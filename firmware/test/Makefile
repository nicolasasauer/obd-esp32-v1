# Makefile – builds and runs the native (host) unit tests for OBD-ESP32
# firmware logic.  No ESP32 toolchain or PlatformIO required.
#
# Usage:
#   make          # build & run
#   make build    # build only
#   make run      # run existing binary
#   make clean    # remove binary

CXX      ?= g++
CXXFLAGS := -std=c++17 -Wall -Wextra -I./mocks -I../include
TARGET   := test_parsebms
SRC      := test_parsebms.cpp

.PHONY: all build run clean

all: build run

build: $(TARGET)

$(TARGET): $(SRC) mocks/Arduino.h mocks/ESP32-TWAI-CAN.hpp mocks/NimBLEDevice.h ../include/config.h ../src/main.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

run: $(TARGET)
	./$(TARGET)

clean:
	$(RM) $(TARGET)
