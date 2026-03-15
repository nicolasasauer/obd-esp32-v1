#pragma once

// ---------------------------------------------------------------------------
// Hardware pin assignments (SN65HVD230 CAN transceiver)
// ---------------------------------------------------------------------------
#define CAN_TX_PIN  GPIO_NUM_5   // CAN TX → SN65HVD230 TXD
#define CAN_RX_PIN  GPIO_NUM_4   // CAN RX → SN65HVD230 RXD

// ---------------------------------------------------------------------------
// CAN / OBD-II settings
// ---------------------------------------------------------------------------
#define CAN_BAUDRATE        500000UL   // 500 kbps (ISO 15765-4)

// Hyundai Ioniq 28 kWh – BMS ECU arbitration IDs
#define BMS_REQUEST_ID      0x7E4      // functional request → BMS
#define BMS_RESPONSE_ID     0x7EC      // BMS response

// UDS service 0x21 (manufacturer-specific data stream)
#define UDS_SERVICE_21      0x21

// PID definitions used for the Hyundai Ioniq BMS
#define PID_BATTERY_SOC_SOH 0x01       // SOC, SOH, pack voltage, current, temps
#define PID_CELL_VOLTAGES   0x02       // Individual cell voltages (frame 1–7)
#define PID_TEMPERATURES    0x05       // Module temperatures

// How long to wait for a CAN response (ms)
#define CAN_RESPONSE_TIMEOUT_MS  100

// Number of consecutive "no CAN data" poll cycles before deep sleep
#define NO_CAN_TIMEOUT_CYCLES    50

// ---------------------------------------------------------------------------
// Deep-sleep duration (µs)  –  wake-up every 30 s and check for CAN traffic
// ---------------------------------------------------------------------------
#define DEEP_SLEEP_US   (30ULL * 1000000ULL)

// ---------------------------------------------------------------------------
// BLE settings
// ---------------------------------------------------------------------------
#define BLE_DEVICE_NAME          "OBD-Ioniq28"

// Service UUID  (128-bit, randomly generated)
#define BLE_SERVICE_UUID         "0000FFE0-0000-1000-8000-00805F9B34FB"

// Notify characteristic UUID (128-bit, randomly generated)
#define BLE_CHAR_NOTIFY_UUID     "0000FFE1-0000-1000-8000-00805F9B34FB"

// ---------------------------------------------------------------------------
// JSON keys sent over BLE
// ---------------------------------------------------------------------------
#define JSON_KEY_SOC     "soc"
#define JSON_KEY_SOH     "soh"
#define JSON_KEY_TEMP    "temp"
#define JSON_KEY_VOLTAGE "voltage"
#define JSON_KEY_CURRENT "current"
