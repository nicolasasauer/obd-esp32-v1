#pragma once
// Minimal ESP32-TWAI-CAN stub for native (host) unit tests.
#include <cstdint>
#include <vector>

/// CAN frame – mirrors the layout used in main.cpp.
struct CanFrame {
    uint32_t identifier       = 0;
    uint8_t  extd             = 0;
    uint8_t  data_length_code = 0;
    uint8_t  data[8]          = {};
};

/// Fake CAN bus – records written frames; supplies injected read frames.
struct _FakeESP32Can {
    std::vector<CanFrame> writtenFrames;
    std::vector<CanFrame> injectFrames;   ///< frames to return on readFrame()
    size_t                injectIdx = 0;

    bool begin()  { return true; }
    void end()    {}

    void setPins(int, int) {}
    void setSpeed(int)     {}
    int  convertSpeed(int kbps) { return kbps; }

    bool readFrame(CanFrame& out, uint32_t /*timeoutMs*/) {
        if (injectIdx < injectFrames.size()) {
            out = injectFrames[injectIdx++];
            return true;
        }
        return false;
    }

    void writeFrame(const CanFrame& f) { writtenFrames.push_back(f); }

    void reset() {
        writtenFrames.clear();
        injectFrames.clear();
        injectIdx = 0;
    }
} ESP32Can;
