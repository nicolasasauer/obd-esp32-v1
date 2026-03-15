/**
 * test_parsebms.cpp – Native (host) unit tests for OBD-ESP32 firmware logic.
 *
 * Tests parseBMSFrame() and notifyBLE() from firmware/src/main.cpp without
 * requiring an ESP32 or PlatformIO toolchain.
 *
 * Build & run:
 *   cd firmware/test
 *   g++ -std=c++17 -Wall -Wextra -I./mocks -I../include \
 *       -o test_parsebms test_parsebms.cpp && ./test_parsebms
 */

// ---------------------------------------------------------------------------
// Mock support variables (declared here, referenced by Arduino.h mock)
// ---------------------------------------------------------------------------
#include <cstdint>
uint32_t g_testMillis = 0;   // controlled by tests to simulate time

// ---------------------------------------------------------------------------
// Include main.cpp as part of this translation unit so that all static
// functions (parseBMSFrame, notifyBLE, …) are accessible.
// The -I./mocks flag ensures that #include <Arduino.h> etc. resolve to our
// stub headers rather than the real embedded-SDK headers.
// ---------------------------------------------------------------------------
#include "../src/main.cpp"

// ---------------------------------------------------------------------------
// Minimal test framework
// ---------------------------------------------------------------------------
#include <cstdio>
#include <cmath>
#include <cstdlib>
#include <string>

static int s_passed = 0;
static int s_failed = 0;

static void assertClose(const char* name, double actual, double expected,
                        double tol = 0.001)
{
    if (std::fabs(actual - expected) <= tol) {
        std::printf("  PASS  %s\n", name);
        ++s_passed;
    } else {
        std::fprintf(stderr,
            "  FAIL  %s  expected=%.4f  actual=%.4f\n",
            name, expected, actual);
        ++s_failed;
    }
}

static void assertEqual(const char* name, const std::string& actual,
                        const std::string& expected)
{
    if (actual == expected) {
        std::printf("  PASS  %s\n", name);
        ++s_passed;
    } else {
        std::fprintf(stderr,
            "  FAIL  %s\n  expected: %s\n  actual:   %s\n",
            name, expected.c_str(), actual.c_str());
        ++s_failed;
    }
}

static void assertTrue(const char* name, bool condition)
{
    if (condition) {
        std::printf("  PASS  %s\n", name);
        ++s_passed;
    } else {
        std::fprintf(stderr, "  FAIL  %s\n", name);
        ++s_failed;
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Reset the global BatteryData to all-zero.
static void resetBattery() { g_battery = BatteryData{}; }

/// Build a CanFrame with data_length_code = 8 and given bytes.
static CanFrame makeFrame(std::initializer_list<uint8_t> bytes)
{
    CanFrame f;
    f.data_length_code = 8;
    int i = 0;
    for (uint8_t b : bytes) { if (i < 8) f.data[i++] = b; }
    return f;
}

// ---------------------------------------------------------------------------
// Tests: parseBMSFrame – first frame
// ---------------------------------------------------------------------------

static void test_firstFrame_soc_and_voltage() {
    // SOC = 82.5 %  → raw = 165  (165 / 2.0 = 82.5)
    // Voltage = 360 V → raw = 3600 = 0x0E10
    CanFrame frame = makeFrame({0x10, 0x00, 0x61, 0x01, 165, 0x0E, 0x10, 0xCC});
    resetBattery();
    parseBMSFrame(frame, true);

    assertClose("firstFrame/soc=82.5",     g_battery.soc,     82.5);
    assertClose("firstFrame/voltage=360V", g_battery.voltage, 360.0);
}

static void test_firstFrame_zero_values() {
    CanFrame frame = makeFrame({0x10, 0x00, 0x61, 0x01, 0, 0, 0, 0xCC});
    resetBattery();
    parseBMSFrame(frame, true);

    assertClose("firstFrame/soc=0",     g_battery.soc,     0.0);
    assertClose("firstFrame/voltage=0", g_battery.voltage, 0.0);
}

static void test_firstFrame_max_values() {
    // SOC 100 % → raw = 200
    // Voltage 600 V → raw = 6000 = 0x1770
    CanFrame frame = makeFrame({0x10, 0x00, 0x61, 0x01, 200, 0x17, 0x70, 0xCC});
    resetBattery();
    parseBMSFrame(frame, true);

    assertClose("firstFrame/soc=100",     g_battery.soc,     100.0);
    assertClose("firstFrame/voltage=600", g_battery.voltage, 600.0);
}

static void test_firstFrame_shortDLC_ignored() {
    CanFrame frame = makeFrame({0x10, 0x00, 0x61, 0x01, 165, 0x0E, 0x10, 0xCC});
    frame.data_length_code = 6;  // too short → must be ignored
    resetBattery();
    parseBMSFrame(frame, true);

    assertClose("firstFrame/shortDLC/soc=0",     g_battery.soc,     0.0);
    assertClose("firstFrame/shortDLC/voltage=0", g_battery.voltage, 0.0);
}

// ---------------------------------------------------------------------------
// Tests: parseBMSFrame – consecutive frame
// ---------------------------------------------------------------------------

static void test_consecutiveFrame_positive_current() {
    // current = +12.5 A (discharging) → raw = 125 = 0x007D
    // SOH = 97.0 % → raw = 194  (194 / 2.0 = 97.0)
    // temp = 24 °C → raw = 64   (64 − 40 = 24)
    CanFrame frame = makeFrame({0x21, 0xCC, 0x00, 0x7D, 194, 0xCC, 64, 0xCC});
    resetBattery();
    parseBMSFrame(frame, false);

    assertClose("consecutiveFrame/current=+12.5", g_battery.current,  12.5);
    assertClose("consecutiveFrame/soh=97",         g_battery.soh,     97.0);
    assertClose("consecutiveFrame/temp=24",         g_battery.temp,    24.0);
}

static void test_consecutiveFrame_negative_current() {
    // current = -12.5 A (charging) → raw (int16) = -125 → 0xFF83
    const int16_t raw = -125;
    const uint8_t hi  = static_cast<uint8_t>((static_cast<uint16_t>(raw) >> 8) & 0xFF);
    const uint8_t lo  = static_cast<uint8_t>( static_cast<uint16_t>(raw)       & 0xFF);
    // SOH = 100 % → raw = 200
    // temp = 0 °C → raw = 40
    CanFrame frame = makeFrame({0x21, 0xCC, hi, lo, 200, 0xCC, 40, 0xCC});
    resetBattery();
    parseBMSFrame(frame, false);

    assertClose("consecutiveFrame/current=-12.5", g_battery.current, -12.5);
    assertClose("consecutiveFrame/soh=100",        g_battery.soh,    100.0);
    assertClose("consecutiveFrame/temp=0",          g_battery.temp,    0.0);
}

static void test_consecutiveFrame_min_temp() {
    // temp = -40 °C → raw = 0  (0 − 40 = −40)
    CanFrame frame = makeFrame({0x21, 0xCC, 0x00, 0x00, 0, 0xCC, 0, 0xCC});
    resetBattery();
    parseBMSFrame(frame, false);

    assertClose("consecutiveFrame/temp=-40", g_battery.temp, -40.0);
}

static void test_consecutiveFrame_max_temp() {
    // temp = 215 °C → raw = 255  (255 − 40 = 215)
    CanFrame frame = makeFrame({0x21, 0xCC, 0x00, 0x00, 0, 0xCC, 255, 0xCC});
    resetBattery();
    parseBMSFrame(frame, false);

    assertClose("consecutiveFrame/temp=215", g_battery.temp, 215.0);
}

static void test_consecutiveFrame_wrongSeq_ignored() {
    // Sequence number 0x22 (not 0x21) – parseBMSFrame should ignore this frame
    CanFrame frame = makeFrame({0x22, 0xCC, 0x01, 0x00, 100, 0xCC, 50, 0xCC});
    resetBattery();
    parseBMSFrame(frame, false);

    assertClose("consecutiveFrame/wrongSeq/current=0", g_battery.current, 0.0);
    assertClose("consecutiveFrame/wrongSeq/soh=0",     g_battery.soh,     0.0);
    assertClose("consecutiveFrame/wrongSeq/temp=0",    g_battery.temp,    0.0);
}

static void test_consecutiveFrame_shortDLC_ignored() {
    CanFrame frame = makeFrame({0x21, 0xCC, 0x00, 0x7D, 194, 0xCC, 64, 0xCC});
    frame.data_length_code = 6;  // too short
    resetBattery();
    parseBMSFrame(frame, false);

    assertClose("consecutiveFrame/shortDLC/current=0", g_battery.current, 0.0);
}

// ---------------------------------------------------------------------------
// Tests: notifyBLE
// ---------------------------------------------------------------------------

static NimBLECharacteristic s_fakeChar;

static void test_notifyBLE_no_crash_when_disconnected() {
    g_bleConnected = false;
    g_notifyChar   = nullptr;
    g_battery      = {50.0f, 95.0f, 22.0f, 350.0f, -5.0f};
    notifyBLE();  // must not crash
    assertTrue("notifyBLE/no_crash_when_disconnected", true);
}

static void test_notifyBLE_json_format() {
    s_fakeChar.lastValue.clear();
    g_bleConnected = true;
    g_notifyChar   = &s_fakeChar;
    g_battery      = {82.5f, 97.0f, 24.5f, 360.0f, -12.5f};
    notifyBLE();

    const std::string expected =
        R"({"soc":82.5,"soh":97.0,"temp":24.5,"voltage":360.0,"current":-12.5})";
    assertEqual("notifyBLE/json_format", s_fakeChar.lastValue, expected);

    g_bleConnected = false;
    g_notifyChar   = nullptr;
}

static void test_notifyBLE_zero_values() {
    s_fakeChar.lastValue.clear();
    g_bleConnected = true;
    g_notifyChar   = &s_fakeChar;
    g_battery      = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
    notifyBLE();

    const std::string expected =
        R"({"soc":0.0,"soh":0.0,"temp":0.0,"voltage":0.0,"current":0.0})";
    assertEqual("notifyBLE/zero_json", s_fakeChar.lastValue, expected);

    g_bleConnected = false;
    g_notifyChar   = nullptr;
}

static void test_notifyBLE_positive_current() {
    s_fakeChar.lastValue.clear();
    g_bleConnected = true;
    g_notifyChar   = &s_fakeChar;
    g_battery      = {75.0f, 100.0f, 30.0f, 380.0f, 15.0f};
    notifyBLE();

    const std::string expected =
        R"({"soc":75.0,"soh":100.0,"temp":30.0,"voltage":380.0,"current":15.0})";
    assertEqual("notifyBLE/positive_current_json", s_fakeChar.lastValue, expected);

    g_bleConnected = false;
    g_notifyChar   = nullptr;
}

// ---------------------------------------------------------------------------
// Tests: sendUDSRequest
// ---------------------------------------------------------------------------

static void test_sendUDSRequest_frame_format() {
    ESP32Can.reset();
    sendUDSRequest(BMS_REQUEST_ID, UDS_SERVICE_21, PID_BATTERY_SOC_SOH);

    assertTrue("sendUDSRequest/one_frame_written",
               ESP32Can.writtenFrames.size() == 1);

    const CanFrame& f = ESP32Can.writtenFrames[0];
    assertTrue("sendUDSRequest/identifier",
               f.identifier == BMS_REQUEST_ID);
    assertTrue("sendUDSRequest/standard_frame",
               f.extd == 0);
    assertTrue("sendUDSRequest/dlc_8",
               f.data_length_code == 8);
    assertTrue("sendUDSRequest/data0_length",
               f.data[0] == 0x02);
    assertTrue("sendUDSRequest/data1_service",
               f.data[1] == UDS_SERVICE_21);
    assertTrue("sendUDSRequest/data2_pid",
               f.data[2] == PID_BATTERY_SOC_SOH);
    // Padding bytes (ISO 15765-4)
    bool paddingOk = true;
    for (int i = 3; i < 8; i++) {
        if (f.data[i] != 0xCC) { paddingOk = false; break; }
    }
    assertTrue("sendUDSRequest/padding_0xCC", paddingOk);
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

int main() {
    std::printf("=== OBD-ESP32 firmware unit tests ===\n\n");

    std::printf("--- parseBMSFrame (first frame) ---\n");
    test_firstFrame_soc_and_voltage();
    test_firstFrame_zero_values();
    test_firstFrame_max_values();
    test_firstFrame_shortDLC_ignored();

    std::printf("\n--- parseBMSFrame (consecutive frame) ---\n");
    test_consecutiveFrame_positive_current();
    test_consecutiveFrame_negative_current();
    test_consecutiveFrame_min_temp();
    test_consecutiveFrame_max_temp();
    test_consecutiveFrame_wrongSeq_ignored();
    test_consecutiveFrame_shortDLC_ignored();

    std::printf("\n--- notifyBLE ---\n");
    test_notifyBLE_no_crash_when_disconnected();
    test_notifyBLE_json_format();
    test_notifyBLE_zero_values();
    test_notifyBLE_positive_current();

    std::printf("\n--- sendUDSRequest ---\n");
    test_sendUDSRequest_frame_format();

    std::printf("\n==============================\n");
    std::printf("Results: %d passed, %d failed\n", s_passed, s_failed);
    return (s_failed > 0) ? 1 : 0;
}
