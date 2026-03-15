import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/battery_data.dart';
import '../providers/battery_provider.dart';
import '../widgets/soc_gauge.dart';
import 'scanner_screen.dart';

/// Main dashboard: SOC gauge + detail values list.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatteryProvider>();
    final data = provider.data;

    // Navigate back to scanner if disconnected
    if (!provider.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F3C),
        title: const Row(
          children: [
            Icon(Icons.electric_car, color: Color(0xFF00B4D8)),
            SizedBox(width: 8),
            Text(
              'Ioniq 28 – Battery',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled, color: Colors.white70),
            tooltip: 'Disconnect',
            onPressed: () => context.read<BatteryProvider>().disconnect(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // SOC gauge
            Center(child: SocGauge(soc: data.soc, size: 240)),

            const SizedBox(height: 32),

            // Detail cards
            _buildDetailGrid(data),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailGrid(BatteryData data) {
    final items = [
      _DetailItem(
        icon: Icons.health_and_safety,
        label: 'State of Health',
        value: '${data.soh.toStringAsFixed(1)} %',
        color: _socColor(data.soh),
      ),
      _DetailItem(
        icon: Icons.thermostat,
        label: 'Battery Temp',
        value: '${data.temp.toStringAsFixed(1)} °C',
        color: _tempColor(data.temp),
      ),
      _DetailItem(
        icon: Icons.bolt,
        label: 'Pack Voltage',
        value: '${data.voltage.toStringAsFixed(1)} V',
        color: const Color(0xFF00B4D8),
      ),
      _DetailItem(
        icon: Icons.electric_meter,
        label: 'Pack Current',
        value: '${data.current > 0 ? "+" : ""}${data.current.toStringAsFixed(1)} A',
        color: data.current > 0
            ? const Color(0xFFE63946)   // discharging → red
            : const Color(0xFF2EC4B6),  // charging → teal
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _DetailCard(item: items[i]),
    );
  }

  static Color _socColor(double v) {
    if (v <= 20) return const Color(0xFFE63946);
    if (v <= 50) return const Color(0xFFFFB703);
    return const Color(0xFF2EC4B6);
  }

  static Color _tempColor(double t) {
    if (t < 5 || t > 40) return const Color(0xFFE63946);
    if (t < 15 || t > 35) return const Color(0xFFFFB703);
    return const Color(0xFF2EC4B6);
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _DetailItem {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.item});
  final _DetailItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F3C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(item.icon, color: item.color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
