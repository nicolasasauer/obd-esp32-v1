/**
 * main.cpp – OBD-II ESP32 firmware for Hyundai Ioniq 28 kWh (vFL)
 *
 * Hardware:
 *   ESP32 DevKit V1  +  SN65HVD230 CAN transceiver
 *
 * Features:
 *   • CAN/TWAI at 500 kbps – ISO 15765-4 UDS request/response
 *   • BMS data polling (SOC, SOH, battery temperature)
 *   • BLE server (NimBLE) with JSON notify characteristic
 *   • Deep sleep when no CAN traffic is detected (protects 12 V battery)
 */

#include <Arduino.h>
#include <ESP32-TWAI-CAN.hpp>
#include <NimBLEDevice.h>

#include "config.h"

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------
struct BatteryData {
    float soc     = 0.0f;   // State of Charge      [%]
    float soh     = 0.0f;   // State of Health       [%]
    float temp    = 0.0f;   // Battery temperature   [°C]
    float voltage = 0.0f;   // Pack voltage          [V]
    float current = 0.0f;   // Pack current          [A]  (positive = discharge)
};

static BatteryData g_battery;
static uint32_t    g_noCanCycles   = 0;    // consecutive cycles with no CAN frame
static bool        g_bleConnected  = false;

// BLE handles
static NimBLEServer*         g_bleServer   = nullptr;
static NimBLECharacteristic* g_notifyChar  = nullptr;

// ---------------------------------------------------------------------------
// BLE server callbacks
// ---------------------------------------------------------------------------
class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* server) override {
        g_bleConnected = true;
        Serial.println("[BLE] Client connected");
    }
    void onDisconnect(NimBLEServer* server) override {
        g_bleConnected = false;
        Serial.println("[BLE] Client disconnected – restarting advertising");
        server->startAdvertising();
    }
};

// ---------------------------------------------------------------------------
// BLE initialisation
// ---------------------------------------------------------------------------
static void initBLE() {
    NimBLEDevice::init(BLE_DEVICE_NAME);
    NimBLEDevice::setPower(ESP_PWR_LVL_P9);   // maximum TX power

    g_bleServer = NimBLEDevice::createServer();
    g_bleServer->setCallbacks(new ServerCallbacks());

    NimBLEService* service = g_bleServer->createService(BLE_SERVICE_UUID);

    g_notifyChar = service->createCharacteristic(
        BLE_CHAR_NOTIFY_UUID,
        NIMBLE_PROPERTY::NOTIFY
    );

    service->start();

    NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising();
    advertising->addServiceUUID(BLE_SERVICE_UUID);
    advertising->setScanResponse(true);
    advertising->start();

    Serial.printf("[BLE] Advertising as '%s'\n", BLE_DEVICE_NAME);
}

// ---------------------------------------------------------------------------
// TWAI (CAN) initialisation
// ---------------------------------------------------------------------------
static bool initCAN() {
    ESP32Can.setPins(CAN_TX_PIN, CAN_RX_PIN);
    ESP32Can.setSpeed(ESP32Can.convertSpeed(500));   // 500 kbps

    if (!ESP32Can.begin()) {
        Serial.println("[CAN] Failed to start TWAI driver!");
        return false;
    }
    Serial.println("[CAN] TWAI driver started at 500 kbps");
    return true;
}

// ---------------------------------------------------------------------------
// Send an ISO 15765-4 single-frame UDS request
//   dlc=8, byte[0]=0x02 (length), byte[1]=service, byte[2]=pid, rest=padding
// ---------------------------------------------------------------------------
static void sendUDSRequest(uint16_t arbId, uint8_t service, uint8_t pid) {
    CanFrame frame;
    frame.identifier = arbId;
    frame.extd       = 0;           // standard 11-bit ID
    frame.data_length_code = 8;
    frame.data[0] = 0x02;           // single frame, 2 data bytes
    frame.data[1] = service;
    frame.data[2] = pid;
    for (int i = 3; i < 8; i++) frame.data[i] = 0xCC;  // ISO padding

    ESP32Can.writeFrame(frame);
}

// ---------------------------------------------------------------------------
// Parse BMS response for PID 0x21 0x01
//
// Hyundai Ioniq 28 kWh BMS (0x7EC) – first frame of multi-frame response:
//   byte  0   : 0x10 or 0x04 (ISO-TP frame type / length)
//   byte  1   : total length
//   byte  2   : 0x61 (positive response to 0x21)
//   byte  3   : PID 0x01
//   byte  4   : SOC raw  (raw/2.0 → %)
//   byte  5-6 : pack voltage raw  (/10 → V)
//   byte  7   : ...
//   ──── consecutive frame ────
//   byte  0   : 0x21
//   ...
//   byte  2-3 : current raw   (signed 16-bit, /10 → A, positive = discharge)
//   byte  4   : SOH raw       (raw/2.0 → %)
//   byte  6   : max temp      (raw − 40 → °C)
//
// NOTE: Exact byte positions are verified against open-source OVMS/CanZE data.
// ---------------------------------------------------------------------------
static void parseBMSFrame(const CanFrame& frame, bool isFirstFrame) {
    if (isFirstFrame) {
        // First frame: bytes 4..6 are meaningful
        if (frame.data_length_code >= 7) {
            uint8_t socRaw     = frame.data[4];
            uint8_t voltHighByte = frame.data[5];
            uint8_t voltLowByte  = frame.data[6];

            g_battery.soc     = socRaw / 2.0f;                          // 0-100 %
            g_battery.voltage = ((voltHighByte << 8) | voltLowByte) / 10.0f;  // V
        }
    } else {
        // Consecutive frame (sequence number 0x21)
        if (frame.data[0] == 0x21 && frame.data_length_code >= 7) {
            int16_t currentRaw = (int16_t)((frame.data[2] << 8) | frame.data[3]);
            uint8_t sohRaw     = frame.data[4];
            uint8_t tempRaw    = frame.data[6];

            g_battery.current = currentRaw / 10.0f;          // A
            g_battery.soh     = sohRaw / 2.0f;               // 0-100 %
            g_battery.temp    = (float)tempRaw - 40.0f;      // °C
        }
    }
}

// ---------------------------------------------------------------------------
// Build a compact JSON string and send it over BLE notify
// Format: {"soc":82.5,"soh":97.0,"temp":24.5,"voltage":360.0,"current":-12.5}
// ---------------------------------------------------------------------------
static void notifyBLE() {
    if (!g_bleConnected || g_notifyChar == nullptr) return;

    char buf[128];
    snprintf(buf, sizeof(buf),
        "{\"" JSON_KEY_SOC "\":%.1f,"
         "\"" JSON_KEY_SOH "\":%.1f,"
         "\"" JSON_KEY_TEMP "\":%.1f,"
         "\"" JSON_KEY_VOLTAGE "\":%.1f,"
         "\"" JSON_KEY_CURRENT "\":%.1f}",
        g_battery.soc,
        g_battery.soh,
        g_battery.temp,
        g_battery.voltage,
        g_battery.current
    );

    g_notifyChar->setValue((uint8_t*)buf, strlen(buf));
    g_notifyChar->notify();
    Serial.printf("[BLE] Notify: %s\n", buf);
}

// ---------------------------------------------------------------------------
// One full BMS poll cycle: request → wait for response → parse → notify
// Returns true if at least one valid CAN response was received.
// ---------------------------------------------------------------------------
static bool pollBMS() {
    // Step 1: send UDS request for PID 0x2101
    sendUDSRequest(BMS_REQUEST_ID, UDS_SERVICE_21, PID_BATTERY_SOC_SOH);

    // Step 2: wait for up to CAN_RESPONSE_TIMEOUT_MS for the first frame
    CanFrame frame;
    bool     gotFirstFrame = false;
    bool     gotConsecutive = false;
    uint32_t deadline = millis() + CAN_RESPONSE_TIMEOUT_MS;

    while (millis() < deadline) {
        if (ESP32Can.readFrame(frame, 5 /* ms */)) {
            if (frame.identifier == BMS_RESPONSE_ID) {
                // Determine frame type from ISO-TP byte
                uint8_t frameType = (frame.data[0] & 0xF0) >> 4;

                if (frameType == 0x1 && !gotFirstFrame) {
                    // First frame of a multi-frame message
                    parseBMSFrame(frame, true);
                    gotFirstFrame = true;

                    // Send flow-control frame (FC) to allow consecutive frames
                    CanFrame fc;
                    fc.identifier        = BMS_REQUEST_ID;
                    fc.extd              = 0;
                    fc.data_length_code  = 8;
                    fc.data[0] = 0x30;  // FC, ContinueToSend
                    fc.data[1] = 0x00;  // block size 0 = no limit
                    fc.data[2] = 0x00;  // separation time 0 ms
                    for (int i = 3; i < 8; i++) fc.data[i] = 0xCC;
                    ESP32Can.writeFrame(fc);

                    // Extend deadline for consecutive frames
                    deadline = millis() + CAN_RESPONSE_TIMEOUT_MS;

                } else if (frameType == 0x2 && gotFirstFrame && !gotConsecutive) {
                    // Consecutive frame
                    parseBMSFrame(frame, false);
                    gotConsecutive = true;
                } else if (frameType == 0x0 && !gotFirstFrame) {
                    // Single frame (short answer)
                    parseBMSFrame(frame, true);
                    gotFirstFrame = true;
                }
            }
        }
    }

    return gotFirstFrame;
}

// ---------------------------------------------------------------------------
// Enter deep sleep – will wake up after DEEP_SLEEP_US microseconds
// ---------------------------------------------------------------------------
static void enterDeepSleep() {
    Serial.printf("[PWR] No CAN activity for %u cycles – entering deep sleep (%llu s)\n",
                  NO_CAN_TIMEOUT_CYCLES, DEEP_SLEEP_US / 1000000ULL);
    Serial.flush();

    ESP32Can.end();                              // cleanly stop TWAI
    NimBLEDevice::deinit(true);                 // cleanly stop BLE

    esp_sleep_enable_timer_wakeup(DEEP_SLEEP_US);
    esp_deep_sleep_start();
}

// ---------------------------------------------------------------------------
// Arduino setup
// ---------------------------------------------------------------------------
void setup() {
    Serial.begin(115200);
    Serial.println("\n\n=== OBD-Ioniq28 firmware starting ===");

    if (!initCAN()) {
        Serial.println("[FATAL] CAN init failed – halting");
        while (true) delay(1000);
    }

    initBLE();
    Serial.println("[SYS] Ready – polling BMS every 500 ms");
}

// ---------------------------------------------------------------------------
// Arduino loop
// ---------------------------------------------------------------------------
void loop() {
    bool gotData = pollBMS();

    if (gotData) {
        g_noCanCycles = 0;
        notifyBLE();
        Serial.printf("[BMS] SOC=%.1f%%  SOH=%.1f%%  Temp=%.1f°C  "
                      "V=%.1fV  I=%.1fA\n",
                      g_battery.soc, g_battery.soh, g_battery.temp,
                      g_battery.voltage, g_battery.current);
    } else {
        g_noCanCycles++;
        Serial.printf("[CAN] No response (%u/%u)\n",
                      g_noCanCycles, NO_CAN_TIMEOUT_CYCLES);

        if (g_noCanCycles >= NO_CAN_TIMEOUT_CYCLES) {
            enterDeepSleep();
        }
    }

    delay(500);   // poll every 500 ms
}
