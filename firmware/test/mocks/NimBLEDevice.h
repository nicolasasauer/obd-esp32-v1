#pragma once
// Minimal NimBLE stub for native (host) unit tests.
#include <cstdint>
#include <cstring>
#include <string>

// Power-level constants
#define ESP_PWR_LVL_P9 9

// Property bitmask
namespace NIMBLE_PROPERTY {
    static constexpr uint32_t NOTIFY = 0x10;
}

/// Records the last value set via setValue/notify.
struct NimBLECharacteristic {
    std::string lastValue;
    void setValue(const uint8_t* buf, size_t len) {
        lastValue = std::string(reinterpret_cast<const char*>(buf), len);
    }
    void notify() {}
};

struct NimBLEServerCallbacks {
    virtual void onConnect(struct NimBLEServer*)    {}
    virtual void onDisconnect(struct NimBLEServer*) {}
    virtual ~NimBLEServerCallbacks() = default;
};

struct NimBLEService {
    NimBLECharacteristic char_;
    NimBLECharacteristic* createCharacteristic(const char*, uint32_t) {
        return &char_;
    }
    void start() {}
};

struct NimBLEAdvertising {
    void addServiceUUID(const char*) {}
    void setScanResponse(bool) {}
    void start() {}
};

struct NimBLEServer {
    NimBLEService svc;
    void setCallbacks(NimBLEServerCallbacks*) {}
    NimBLEService* createService(const char*) { return &svc; }
    void startAdvertising() {}
};

/// NimBLEDevice with static interface (mirrors real NimBLE API).
class NimBLEDevice {
public:
    static NimBLEServer  s_server;
    static NimBLEAdvertising s_adv;

    static void         init(const char*)       {}
    static void         setPower(int)           {}
    static void         deinit(bool)            {}
    static NimBLEServer*      createServer()   { return &s_server; }
    static NimBLEAdvertising* getAdvertising() { return &s_adv; }
};

// Out-of-line definitions for static members
inline NimBLEServer      NimBLEDevice::s_server;
inline NimBLEAdvertising NimBLEDevice::s_adv;

// esp_sleep stubs (used in enterDeepSleep)
inline void esp_sleep_enable_timer_wakeup(uint64_t) {}
inline void esp_deep_sleep_start() {}
