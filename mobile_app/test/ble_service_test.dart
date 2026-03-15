import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:obd_app/models/battery_data.dart';
import 'package:obd_app/services/ble_service.dart';

// ---------------------------------------------------------------------------
// Standalone helper that replicates BleService._onData parsing logic so we
// can test JSON → BatteryData conversion without a real BLE stack.
// ---------------------------------------------------------------------------

/// Parses a raw BLE notification payload (UTF-8 JSON) into [BatteryData].
/// Returns null if the bytes are not valid UTF-8 or not a JSON object.
BatteryData? parseBlePayload(List<int> bytes) {
  try {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return BatteryData.fromJson(json);
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BleService – BLE payload parsing (parseBlePayload)', () {
    test('parses a valid full JSON payload', () {
      final bytes = utf8.encode(
        '{"soc":82.5,"soh":97.0,"temp":24.5,"voltage":360.0,"current":-12.5}',
      );

      final data = parseBlePayload(bytes);

      expect(data, isNotNull);
      expect(data!.soc,     closeTo(82.5,   0.001));
      expect(data.soh,      closeTo(97.0,   0.001));
      expect(data.temp,     closeTo(24.5,   0.001));
      expect(data.voltage,  closeTo(360.0,  0.001));
      expect(data.current,  closeTo(-12.5,  0.001));
    });

    test('returns null for malformed JSON', () {
      final bytes = utf8.encode('{not valid json}');
      expect(parseBlePayload(bytes), isNull);
    });

    test('returns null for empty byte list', () {
      expect(parseBlePayload([]), isNull);
    });

    test('returns null for non-UTF-8 bytes', () {
      // Inject invalid UTF-8 sequence
      expect(parseBlePayload([0xFF, 0xFE, 0x00]), isNull);
    });

    test('handles missing JSON fields with defaults', () {
      final bytes = utf8.encode('{"soc":45.0}');
      final data = parseBlePayload(bytes);

      expect(data, isNotNull);
      expect(data!.soc,     closeTo(45.0, 0.001));
      expect(data.soh,     0.0);
      expect(data.temp,    0.0);
      expect(data.voltage, 0.0);
      expect(data.current, 0.0);
    });

    test('handles integer JSON values', () {
      final bytes = utf8.encode(
        '{"soc":80,"soh":95,"temp":22,"voltage":355,"current":0}',
      );

      final data = parseBlePayload(bytes);
      expect(data, isNotNull);
      expect(data!.soc,     80.0);
      expect(data.soh,     95.0);
      expect(data.temp,    22.0);
      expect(data.voltage, 355.0);
      expect(data.current,  0.0);
    });

    test('handles positive current (discharging)', () {
      final bytes = utf8.encode(
        '{"soc":70.0,"soh":98.0,"temp":26.0,"voltage":362.0,"current":15.5}',
      );

      final data = parseBlePayload(bytes);
      expect(data, isNotNull);
      expect(data!.current, closeTo(15.5, 0.001));
      expect(data.current,  greaterThan(0));
    });

    test('handles negative current (charging)', () {
      final bytes = utf8.encode(
        '{"soc":30.0,"soh":92.0,"temp":20.0,"voltage":335.0,"current":-22.0}',
      );

      final data = parseBlePayload(bytes);
      expect(data, isNotNull);
      expect(data!.current, closeTo(-22.0, 0.001));
      expect(data.current,  lessThan(0));
    });

    test('returns null for JSON array instead of object', () {
      final bytes = utf8.encode('[1,2,3]');
      expect(parseBlePayload(bytes), isNull);
    });

    test('returns null for JSON primitive', () {
      final bytes = utf8.encode('"hello"');
      expect(parseBlePayload(bytes), isNull);
    });

    test('handles empty JSON object with all defaults', () {
      final bytes = utf8.encode('{}');
      final data = parseBlePayload(bytes);
      expect(data, isNotNull);
      expect(data!.soc, 0.0);
    });

    test('parses the exact JSON format produced by firmware', () {
      // This is the exact format produced by main.cpp's snprintf format string.
      const firmwareJson =
          '{"soc":82.5,"soh":97.0,"temp":24.5,"voltage":360.0,"current":-12.5}';
      final bytes = utf8.encode(firmwareJson);
      final data = parseBlePayload(bytes);

      expect(data, isNotNull);
      expect(data!.soc,     closeTo(82.5,   0.001));
      expect(data.soh,      closeTo(97.0,   0.001));
      expect(data.temp,     closeTo(24.5,   0.001));
      expect(data.voltage,  closeTo(360.0,  0.001));
      expect(data.current,  closeTo(-12.5,  0.001));
    });
  });

  group('BleService – UUID constants', () {
    test('service UUID is lowercase', () {
      expect(kServiceUuid, kServiceUuid.toLowerCase());
    });

    test('characteristic UUID is lowercase', () {
      expect(kCharUuid, kCharUuid.toLowerCase());
    });

    test('device name matches firmware BLE_DEVICE_NAME', () {
      expect(kDeviceName, 'OBD-Ioniq28');
    });

    test('service UUID matches firmware BLE_SERVICE_UUID (lowercased)', () {
      // Firmware: "0000FFE0-0000-1000-8000-00805F9B34FB"
      const firmwareUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
      expect(kServiceUuid, firmwareUuid.toLowerCase());
    });

    test('char UUID matches firmware BLE_CHAR_NOTIFY_UUID (lowercased)', () {
      const firmwareUuid = '0000FFE1-0000-1000-8000-00805F9B34FB';
      expect(kCharUuid, firmwareUuid.toLowerCase());
    });
  });
}
