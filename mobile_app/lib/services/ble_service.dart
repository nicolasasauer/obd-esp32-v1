import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/battery_data.dart';

/// UUIDs must match firmware config.h
const String kServiceUuid  = '0000ffe0-0000-1000-8000-00805f9b34fb';
const String kCharUuid     = '0000ffe1-0000-1000-8000-00805f9b34fb';
const String kDeviceName   = 'OBD-Ioniq28';

// ---------------------------------------------------------------------------
// Abstract interface – allows injecting a fake for unit tests.
// ---------------------------------------------------------------------------

/// Contract that [BatteryProvider] depends on.
/// The concrete [BleService] implements the real BLE stack; tests can supply
/// a lightweight fake without a real Bluetooth adapter.
abstract class BleServiceBase {
  Stream<BatteryData> get dataStream;

  /// Scans for the ESP32 and returns an opaque device token.
  Future<Object> scanForDevice({Duration timeout});

  /// Connects to [device] (the token returned by [scanForDevice]).
  Future<void> connect(Object device);

  /// Disconnects and releases all BLE resources.
  Future<void> disconnect();

  void dispose();
}

// ---------------------------------------------------------------------------
// Real implementation
// ---------------------------------------------------------------------------

/// Manages BLE scanning, connection, and data parsing.
class BleService extends BleServiceBase {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyChar;
  StreamSubscription<List<int>>? _notifySub;

  final _dataController = StreamController<BatteryData>.broadcast();

  /// Stream of parsed [BatteryData] updates from the ESP32.
  @override
  Stream<BatteryData> get dataStream => _dataController.stream;

  /// Starts a BLE scan and resolves with the first matching [BluetoothDevice].
  /// Throws a [TimeoutException] if no device is found within [timeout].
  @override
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
  @override
  Future<void> connect(Object device) async {
    final bt = device as BluetoothDevice;
    _device = bt;

    await bt.connect(autoConnect: false);

    final services = await bt.discoverServices();
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
  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    _notifyChar = null;
    await _device?.disconnect();
    _device = null;
  }

  @override
  void dispose() {
    unawaited(disconnect());
    _dataController.close();
  }
}
