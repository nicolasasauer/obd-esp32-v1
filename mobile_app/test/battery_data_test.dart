import 'package:flutter_test/flutter_test.dart';

import 'package:obd_app/models/battery_data.dart';

void main() {
  group('BatteryData.fromJson', () {
    test('parses a full JSON map correctly', () {
      final data = BatteryData.fromJson({
        'soc': 82.5,
        'soh': 97.0,
        'temp': 24.5,
        'voltage': 360.0,
        'current': -12.5,
      });

      expect(data.soc,     closeTo(82.5, 0.001));
      expect(data.soh,     closeTo(97.0, 0.001));
      expect(data.temp,    closeTo(24.5, 0.001));
      expect(data.voltage, closeTo(360.0, 0.001));
      expect(data.current, closeTo(-12.5, 0.001));
    });

    test('handles missing fields with 0.0 defaults', () {
      final data = BatteryData.fromJson({});

      expect(data.soc,     0.0);
      expect(data.soh,     0.0);
      expect(data.temp,    0.0);
      expect(data.voltage, 0.0);
      expect(data.current, 0.0);
    });

    test('accepts integer values and converts them to double', () {
      final data = BatteryData.fromJson({
        'soc': 75,
        'soh': 100,
        'temp': 22,
        'voltage': 380,
        'current': 0,
      });

      expect(data.soc,     75.0);
      expect(data.soh,     100.0);
      expect(data.temp,    22.0);
      expect(data.voltage, 380.0);
      expect(data.current, 0.0);
    });

    test('empty constant returns zero values', () {
      const data = BatteryData.empty;

      expect(data.soc,     0.0);
      expect(data.soh,     0.0);
      expect(data.temp,    0.0);
      expect(data.voltage, 0.0);
      expect(data.current, 0.0);
    });
  });
}
