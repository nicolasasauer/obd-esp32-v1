import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/battery_data.dart';

/// UUIDs must match firmware config.h
const String kServiceUuid  = '0000ffe0-0000-1000-8000-00805f9b34fb';
const String kCharUuid     = '0000ffe1-0000-1000-8000-00805f9b34fb';
const String kDeviceName   = 'OBD-Ioniq28';

/// Manages BLE scanning, connection, and data parsing.
class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyChar;
  StreamSubscription<List<int>>? _notifySub;

  final _dataController = StreamController<BatteryData>.broadcast();

  /// Stream of parsed [BatteryData] updates from the ESP32.
  Stream<BatteryData> get dataStream => _dataController.stream;

  /// Starts a BLE scan and resolves with the first matching [BluetoothDevice].
  /// Throws a [TimeoutException] if no device is found within [timeout].
  Future<BluetoothDevice> scanForDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final completer = Completer<BluetoothDevice>();

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == kDeviceName) {
          if (!completer.isCompleted) completer.complete(r.device);
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [Guid(kServiceUuid)],
      timeout: timeout,
    );

    final device = await completer.future.timeout(timeout, onTimeout: () {
      sub.cancel();
      FlutterBluePlus.stopScan();
      throw TimeoutException('ESP32 "$kDeviceName" not found within scan timeout');
    });

    await sub.cancel();
    await FlutterBluePlus.stopScan();
    return device;
  }

  /// Connects to [device], discovers services, and subscribes to notifications.
  Future<void> connect(BluetoothDevice device) async {
    _device = device;

    await device.connect(autoConnect: false);

    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == kServiceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == kCharUuid) {
            _notifyChar = char;
            break;
          }
        }
      }
    }

    if (_notifyChar == null) {
      throw Exception('Notify characteristic not found on device');
    }

    await _notifyChar!.setNotifyValue(true);
    _notifySub = _notifyChar!.onValueReceived.listen(_onData);
  }

  void _onData(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      _dataController.add(BatteryData.fromJson(json));
    } catch (e) {
      // Ignore malformed frames
    }
  }

  /// Disconnects from the current device and cleans up resources.
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    _notifyChar = null;
    await _device?.disconnect();
    _device = null;
  }

  void dispose() {
    unawaited(disconnect());
    _dataController.close();
  }
}
