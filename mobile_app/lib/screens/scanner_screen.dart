import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/battery_provider.dart';
import 'dashboard_screen.dart';

/// Initial screen: shows a BLE scan button.
/// Automatically navigates to [DashboardScreen] once connected.
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatteryProvider>();

    // Navigate to dashboard once connected
    if (provider.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00B4D8).withOpacity(0.15),
                    border: Border.all(
                      color: const Color(0xFF00B4D8),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.electric_car,
                    size: 52,
                    color: Color(0xFF00B4D8),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'OBD Ioniq 28',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect to your ESP32 OBD dongle\nvia Bluetooth Low Energy',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, height: 1.5),
                ),

                const SizedBox(height: 48),

                // Status indicator
                _buildStatus(provider),

                const SizedBox(height: 32),

                // Connect / Disconnect button
                _buildActionButton(context, provider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(BatteryProvider provider) {
    String label;
    Color color;
    IconData icon;

    switch (provider.state) {
      case DeviceConnectionState.scanning:
        label = 'Scanning for OBD-Ioniq28…';
        color = Colors.amber;
        icon = Icons.bluetooth_searching;
      case DeviceConnectionState.connecting:
        label = 'Connecting…';
        color = Colors.amber;
        icon = Icons.bluetooth_connected;
      case DeviceConnectionState.connected:
        label = 'Connected';
        color = Colors.greenAccent;
        icon = Icons.bluetooth_connected;
      case DeviceConnectionState.error:
        label = provider.errorMessage;
        color = Colors.redAccent;
        icon = Icons.error_outline;
      case DeviceConnectionState.disconnected:
        label = 'Not connected';
        color = Colors.white38;
        icon = Icons.bluetooth_disabled;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        provider.isScanning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.amber,
                ),
              )
            : Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, BatteryProvider provider) {
    final isIdle = provider.state == DeviceConnectionState.disconnected ||
        provider.state == DeviceConnectionState.error;

    return ElevatedButton.icon(
      onPressed: isIdle
          ? () => context.read<BatteryProvider>().startScanAndConnect()
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00B4D8),
        foregroundColor: Colors.black,
        minimumSize: const Size(220, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      icon: const Icon(Icons.bluetooth_searching),
      label: Text(
        isIdle ? 'Scan & Connect' : 'Connecting…',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
