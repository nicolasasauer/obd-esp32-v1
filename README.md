# obd-esp32-v1

DIY OBD-II data logger for the **Hyundai Ioniq 28 kWh (vFL)**.  
An ESP32 reads BMS data over CAN and streams it via BLE to a Flutter mobile app.

---

## Repository structure

```
obd-esp32-v1/
├── firmware/          ESP32 Arduino / PlatformIO project
│   ├── platformio.ini
│   ├── include/
│   │   └── config.h   pin assignments, UUIDs, PID constants
│   └── src/
│       └── main.cpp   CAN polling, BLE server, deep-sleep logic
│
└── mobile_app/        Flutter application (Android / iOS)
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── models/       BatteryData model
        ├── services/     BleService (scanner + parser)
        ├── providers/    BatteryProvider (state management)
        ├── screens/      ScannerScreen, DashboardScreen
        └── widgets/      SocGauge (CustomPaint)
```

---

## Firmware

### Hardware

| Component | Value |
|-----------|-------|
| Microcontroller | ESP32 DevKit V1 |
| CAN transceiver | SN65HVD230 |
| CAN TX pin | GPIO 5 |
| CAN RX pin | GPIO 4 |

### Features

- **TWAI (CAN) at 500 kbps** – ISO 15765-4 compliant
- **UDS requests to BMS ECU (0x7E4)** – parses SOC, SOH, battery temperature, pack voltage & current from PID `0x2101`
- **BLE Server (NimBLE)** – advertises as `OBD-Ioniq28`, sends JSON via a Notify characteristic
- **Deep sleep** – enters 30-second deep sleep when no CAN traffic is detected for 50 consecutive poll cycles (protects 12 V battery)

### Build & flash

```bash
cd firmware
pio run --target upload
pio device monitor
```

> Requires [PlatformIO](https://platformio.org/) (VS Code extension or CLI).

### BLE JSON format

```json
{"soc":82.5,"soh":97.0,"temp":24.5,"voltage":360.0,"current":-12.5}
```

| Key | Unit | Description |
|-----|------|-------------|
| `soc` | % | State of Charge |
| `soh` | % | State of Health |
| `temp` | °C | Battery pack temperature |
| `voltage` | V | Pack voltage |
| `current` | A | Pack current (positive = discharging) |

---

## Mobile App (Flutter)

### Features

- **BLE Scanner** – searches for `OBD-Ioniq28` and connects automatically
- **SOC Gauge** – custom-painted circular arc gauge with colour coding
  - ≤ 20 % → red · ≤ 50 % → amber · > 50 % → teal
- **Detail cards** – SOH, temperature, pack voltage, current
- **State management** – `provider` + `ChangeNotifier`
- **Auto-reconnect** – returns to scanner screen on disconnect

### Run

```bash
cd mobile_app
flutter pub get
flutter run
```

### Test

```bash
cd mobile_app
flutter test
```

---

## Wiring diagram

```
ESP32 DevKit V1                SN65HVD230
─────────────                 ──────────
GPIO 5 (TX)   ──────────────► TXD
GPIO 4 (RX)   ◄────────────── RXD
3.3 V         ──────────────► VCC
GND           ──────────────► GND
                               CANH ──► OBD-II pin 6
                               CANL ──► OBD-II pin 14
```

---

## License

MIT
