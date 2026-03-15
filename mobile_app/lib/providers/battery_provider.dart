import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/battery_data.dart';
import '../services/ble_service.dart';

enum DeviceConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Central state-management class for BLE and battery data.
/// Exposed via [ChangeNotifierProvider] from [main.dart].
class BatteryProvider extends ChangeNotifier {
  /// Allows injecting a custom [BleServiceBase] (e.g. a fake for tests).
  BatteryProvider({BleServiceBase? bleService}) : _ble = bleService ?? BleService();

  final BleServiceBase _ble;

  BatteryData _data = BatteryData.empty;
  DeviceConnectionState _state = DeviceConnectionState.disconnected;
  String _errorMessage = '';
  StreamSubscription<BatteryData>? _dataSub;

  // ── public getters ────────────────────────────────────────────────────────

  BatteryData get data            => _data;
  DeviceConnectionState get state       => _state;
  String get errorMessage         => _errorMessage;
  bool get isConnected            => _state == DeviceConnectionState.connected;
  bool get isScanning             => _state == DeviceConnectionState.scanning;

  // ── actions ───────────────────────────────────────────────────────────────

  /// Starts a BLE scan and, on success, connects to the ESP32.
  Future<void> startScanAndConnect() async {
    _setState(DeviceConnectionState.scanning);
    _errorMessage = '';

    try {
      final device = await _ble.scanForDevice();
      _setState(DeviceConnectionState.connecting);

      await _ble.connect(device);
      _setState(DeviceConnectionState.connected);

      _dataSub = _ble.dataStream.listen((data) {
        _data = data;
        notifyListeners();
      });
    } on TimeoutException {
      await _ble.disconnect();
      _setError('Device not found. Make sure the ESP32 is powered and nearby.');
    } catch (e) {
      await _ble.disconnect();
      _setError('Connection failed: $e');
    }
  }

  /// Disconnects from the ESP32.
  Future<void> disconnect() async {
    await _dataSub?.cancel();
    _dataSub = null;
    await _ble.disconnect();
    _data = BatteryData.empty;
    _setState(DeviceConnectionState.disconnected);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  void _setState(DeviceConnectionState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _state = DeviceConnectionState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _ble.dispose();
    super.dispose();
  }
}
