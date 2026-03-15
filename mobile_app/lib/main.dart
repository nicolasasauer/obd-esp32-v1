import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/battery_provider.dart';
import 'screens/scanner_screen.dart';

void main() {
  runApp(const ObdApp());
}

class ObdApp extends StatelessWidget {
  const ObdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BatteryProvider(),
      child: MaterialApp(
        title: 'OBD Ioniq 28',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00B4D8),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const ScannerScreen(),
      ),
    );
  }
}
