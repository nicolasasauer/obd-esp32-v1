#pragma once
// Minimal Arduino.h stub for native (host) unit tests.
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cmath>

// Fake Serial
struct _FakeSerial {
    template<typename T>       void print(T)   {}
    template<typename T>       void println(T) {}
    template<typename... Args> void printf(const char* fmt, Args... args) {
        ::printf(fmt, args...);
    }
    void flush() {}
    void begin(int) {}
} Serial;

// millis() / delay() stubs – test code can advance g_testMillis as needed
extern uint32_t g_testMillis;
inline uint32_t millis()     { return g_testMillis; }
inline void delay(uint32_t)  {}

// GPIO pin constants
#define GPIO_NUM_4 4
#define GPIO_NUM_5 5
