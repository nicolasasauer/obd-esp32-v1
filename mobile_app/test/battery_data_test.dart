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

    test('handles null field values with 0.0 defaults', () {
      final data = BatteryData.fromJson({
        'soc': null,
        'soh': null,
        'temp': null,
        'voltage': null,
        'current': null,
      });

      expect(data.soc,     0.0);
      expect(data.soh,     0.0);
      expect(data.temp,    0.0);
      expect(data.voltage, 0.0);
      expect(data.current, 0.0);
    });

    test('handles extra unknown fields gracefully', () {
      final data = BatteryData.fromJson({
        'soc': 50.0,
        'soh': 90.0,
        'temp': 20.0,
        'voltage': 370.0,
        'current': 5.0,
        'unknown_field': 'ignored',
        'another_field': 42,
      });

      expect(data.soc,     50.0);
      expect(data.soh,     90.0);
      expect(data.temp,    20.0);
      expect(data.voltage, 370.0);
      expect(data.current, 5.0);
    });

    test('handles extreme boundary values', () {
      final data = BatteryData.fromJson({
        'soc': 100.0,
        'soh': 100.0,
        'temp': -40.0,
        'voltage': 0.0,
        'current': -9999.9,
      });

      expect(data.soc,     100.0);
      expect(data.soh,     100.0);
      expect(data.temp,    closeTo(-40.0, 0.001));
      expect(data.voltage, 0.0);
      expect(data.current, closeTo(-9999.9, 0.001));
    });

    test('handles positive current (discharging) correctly', () {
      final data = BatteryData.fromJson({
        'soc': 60.0,
        'soh': 95.0,
        'temp': 25.0,
        'voltage': 355.0,
        'current': 12.5,
      });

      expect(data.current, closeTo(12.5, 0.001));
      expect(data.current, greaterThan(0));
    });

    test('handles negative current (charging) correctly', () {
      final data = BatteryData.fromJson({
        'soc': 40.0,
        'soh': 98.0,
        'temp': 18.0,
        'voltage': 340.0,
        'current': -7.3,
      });

      expect(data.current, closeTo(-7.3, 0.001));
      expect(data.current, lessThan(0));
    });
  });

  group('BatteryData.toString', () {
    test('returns expected string format', () {
      const data = BatteryData(
        soc: 82.5,
        soh: 97.0,
        temp: 24.5,
        voltage: 360.0,
        current: -12.5,
      );

      final str = data.toString();

      expect(str, contains('soc=82.5'));
      expect(str, contains('soh=97.0'));
      expect(str, contains('temp=24.5'));
      expect(str, contains('voltage=360.0'));
      expect(str, contains('current=-12.5'));
    });

    test('empty constant toString contains zero values', () {
      const data = BatteryData.empty;
      final str = data.toString();

      expect(str, contains('soc=0'));
      expect(str, contains('soh=0'));
      expect(str, contains('temp=0'));
      expect(str, contains('voltage=0'));
      expect(str, contains('current=0'));
    });

    test('toString includes unit suffixes', () {
      const data = BatteryData(
        soc: 50.0,
        soh: 90.0,
        temp: 20.0,
        voltage: 350.0,
        current: 0.0,
      );

      final str = data.toString();

      expect(str, contains('%'));
      expect(str, contains('°C'));
      expect(str, contains('V'));
      expect(str, contains('A'));
    });
  });

  group('BatteryData immutability', () {
    test('two fromJson calls with the same data produce equal field values', () {
      const json = {
        'soc': 80.0,
        'soh': 95.0,
        'temp': 22.0,
        'voltage': 358.0,
        'current': -3.0,
      };

      final a = BatteryData.fromJson(json);
      final b = BatteryData.fromJson(json);

      expect(a.soc,     b.soc);
      expect(a.soh,     b.soh);
      expect(a.temp,    b.temp);
      expect(a.voltage, b.voltage);
      expect(a.current, b.current);
    });
  });
}
