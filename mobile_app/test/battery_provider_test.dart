import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:obd_app/models/battery_data.dart';
import 'package:obd_app/providers/battery_provider.dart';
import 'package:obd_app/services/ble_service.dart';

// ---------------------------------------------------------------------------
// Fake BleService implementation – no real BLE hardware required.
// ---------------------------------------------------------------------------

/// Sentinel device token returned by FakeBleService.scanForDevice.
class _FakeDevice {
  final String? connectError;
  _FakeDevice({this.connectError});
}

class FakeBleService extends BleServiceBase {
  /// Configure what `scanForDevice` should return / throw.
  Object? _scanResult;

  /// Track how many times disconnect() was called.
  int disconnectCalls = 0;

  final _controller = StreamController<BatteryData>.broadcast();

  @override
  Stream<BatteryData> get dataStream => _controller.stream;

  void setScanSuccess() => _scanResult = _FakeDevice();

  void setScanTimeout() =>
      _scanResult = TimeoutException('scan timeout');

  void setScanError(String msg) =>
      _scanResult = Exception(msg);

  void setConnectError(String msg) =>
      _scanResult = _FakeDevice(connectError: msg);

  void emitData(BatteryData d) => _controller.add(d);

  @override
  Future<Object> scanForDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final r = _scanResult;
    if (r is TimeoutException) throw r;
    if (r is Exception) throw r;
    return r!;
  }

  @override
  Future<void> connect(Object device) async {
    if (device is _FakeDevice && device.connectError != null) {
      throw Exception(device.connectError);
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeBleService fakeBle;
  late BatteryProvider provider;

  setUp(() {
    fakeBle  = FakeBleService();
    provider = BatteryProvider(bleService: fakeBle);
  });

  tearDown(() {
    provider.dispose();
  });

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('starts disconnected', () {
      expect(provider.state, DeviceConnectionState.disconnected);
    });

    test('isConnected is false initially', () {
      expect(provider.isConnected, isFalse);
    });

    test('isScanning is false initially', () {
      expect(provider.isScanning, isFalse);
    });

    test('errorMessage is empty initially', () {
      expect(provider.errorMessage, isEmpty);
    });

    test('data is BatteryData.empty initially', () {
      expect(provider.data.soc,     0.0);
      expect(provider.data.soh,     0.0);
      expect(provider.data.temp,    0.0);
      expect(provider.data.voltage, 0.0);
      expect(provider.data.current, 0.0);
    });
  });

  // ── Successful connect ─────────────────────────────────────────────────────

  group('startScanAndConnect – success', () {
    test('transitions through scanning → connecting → connected', () async {
      fakeBle.setScanSuccess();

      final states = <DeviceConnectionState>[];
      provider.addListener(() => states.add(provider.state));

      await provider.startScanAndConnect();

      expect(states, containsAllInOrder([
        DeviceConnectionState.scanning,
        DeviceConnectionState.connecting,
        DeviceConnectionState.connected,
      ]));
    });

    test('isConnected is true after successful connect', () async {
      fakeBle.setScanSuccess();
      await provider.startScanAndConnect();

      expect(provider.isConnected, isTrue);
    });

    test('data updates when BLE stream emits', () async {
      fakeBle.setScanSuccess();
      await provider.startScanAndConnect();

      const newData = BatteryData(
        soc: 75.0, soh: 95.0, temp: 22.0, voltage: 355.0, current: -5.0,
      );

      final notified = Completer<void>();
      provider.addListener(() {
        if (provider.data.soc == 75.0) notified.complete();
      });

      fakeBle.emitData(newData);

      await notified.future.timeout(const Duration(seconds: 1));

      expect(provider.data.soc,     75.0);
      expect(provider.data.soh,     95.0);
      expect(provider.data.temp,    22.0);
      expect(provider.data.voltage, 355.0);
      expect(provider.data.current, -5.0);
    });
  });

  // ── Scan timeout ───────────────────────────────────────────────────────────

  group('startScanAndConnect – scan timeout', () {
    test('transitions to error state on timeout', () async {
      fakeBle.setScanTimeout();
      await provider.startScanAndConnect();

      expect(provider.state, DeviceConnectionState.error);
    });

    test('errorMessage is set on timeout', () async {
      fakeBle.setScanTimeout();
      await provider.startScanAndConnect();

      expect(provider.errorMessage, isNotEmpty);
    });

    test('disconnect is called for cleanup on timeout', () async {
      fakeBle.setScanTimeout();
      await provider.startScanAndConnect();

      expect(fakeBle.disconnectCalls, greaterThanOrEqualTo(1));
    });

    test('isConnected is false after timeout', () async {
      fakeBle.setScanTimeout();
      await provider.startScanAndConnect();

      expect(provider.isConnected, isFalse);
    });
  });

  // ── Scan generic error ─────────────────────────────────────────────────────

  group('startScanAndConnect – generic scan error', () {
    test('transitions to error state on exception', () async {
      fakeBle.setScanError('BLE unavailable');
      await provider.startScanAndConnect();

      expect(provider.state, DeviceConnectionState.error);
    });

    test('errorMessage includes exception text', () async {
      fakeBle.setScanError('BLE unavailable');
      await provider.startScanAndConnect();

      expect(provider.errorMessage, contains('BLE unavailable'));
    });

    test('disconnect is called for cleanup on error', () async {
      fakeBle.setScanError('BLE unavailable');
      await provider.startScanAndConnect();

      expect(fakeBle.disconnectCalls, greaterThanOrEqualTo(1));
    });
  });

  // ── Connect error (characteristic not found, etc.) ────────────────────────

  group('startScanAndConnect – connect error', () {
    test('transitions to error state when connect throws', () async {
      fakeBle.setConnectError('Characteristic not found');
      await provider.startScanAndConnect();

      expect(provider.state, DeviceConnectionState.error);
    });

    test('disconnect is called to clean up partial connection', () async {
      fakeBle.setConnectError('Characteristic not found');
      await provider.startScanAndConnect();

      expect(fakeBle.disconnectCalls, greaterThanOrEqualTo(1));
    });
  });

  // ── Disconnect ─────────────────────────────────────────────────────────────

  group('disconnect', () {
    test('returns to disconnected state', () async {
      fakeBle.setScanSuccess();
      await provider.startScanAndConnect();
      expect(provider.isConnected, isTrue);

      await provider.disconnect();

      expect(provider.state, DeviceConnectionState.disconnected);
    });

    test('resets data to empty on disconnect', () async {
      fakeBle.setScanSuccess();
      await provider.startScanAndConnect();

      const newData = BatteryData(
        soc: 80.0, soh: 90.0, temp: 25.0, voltage: 360.0, current: 0.0,
      );
      fakeBle.emitData(newData);

      // Give the stream a moment to deliver
      await Future<void>.delayed(Duration.zero);

      await provider.disconnect();

      expect(provider.data.soc,     0.0);
      expect(provider.data.voltage, 0.0);
    });

    test('isConnected is false after disconnect', () async {
      fakeBle.setScanSuccess();
      await provider.startScanAndConnect();

      await provider.disconnect();

      expect(provider.isConnected, isFalse);
    });
  });

  // ── Retry after error ──────────────────────────────────────────────────────

  group('retry after error', () {
    test('can successfully connect after a previous timeout', () async {
      fakeBle.setScanTimeout();
      await provider.startScanAndConnect();
      expect(provider.state, DeviceConnectionState.error);

      fakeBle.setScanSuccess();
      await provider.startScanAndConnect();
      expect(provider.state, DeviceConnectionState.connected);
    });
  });
}
