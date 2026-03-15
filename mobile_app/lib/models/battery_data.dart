/// Data model that mirrors the JSON sent by the ESP32 firmware.
///
/// JSON format:
/// {"soc":82.5,"soh":97.0,"temp":24.5,"voltage":360.0,"current":-12.5}
class BatteryData {
  final double soc;      // State of Charge     [%]   0–100
  final double soh;      // State of Health     [%]   0–100
  final double temp;     // Battery temperature [°C]
  final double voltage;  // Pack voltage        [V]
  final double current;  // Pack current        [A]  (+ discharge / − charge)

  const BatteryData({
    required this.soc,
    required this.soh,
    required this.temp,
    required this.voltage,
    required this.current,
  });

  /// Parses the JSON map received from the BLE characteristic.
  factory BatteryData.fromJson(Map<String, dynamic> json) {
    return BatteryData(
      soc:     (json['soc']     as num?)?.toDouble() ?? 0.0,
      soh:     (json['soh']     as num?)?.toDouble() ?? 0.0,
      temp:    (json['temp']    as num?)?.toDouble() ?? 0.0,
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Returns an empty / initial data object.
  static const BatteryData empty = BatteryData(
    soc: 0,
    soh: 0,
    temp: 0,
    voltage: 0,
    current: 0,
  );

  /// Human-readable string for debugging.
  @override
  String toString() =>
      'BatteryData(soc=$soc%, soh=$soh%, temp=${temp}°C, '
      'voltage=${voltage}V, current=${current}A)';
}
