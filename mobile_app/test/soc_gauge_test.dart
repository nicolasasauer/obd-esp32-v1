import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:obd_app/widgets/soc_gauge.dart';

// Helper to pump the gauge inside a minimal Material app.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SocGauge widget', () {
    testWidgets('renders without error for mid-range SOC', (tester) async {
      await tester.pumpWidget(_wrap(const SocGauge(soc: 50.0)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows SOC percentage text', (tester) async {
      await tester.pumpWidget(_wrap(const SocGauge(soc: 82.5)));
      expect(find.textContaining('82.5'), findsOneWidget);
      expect(find.textContaining('%'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows SOC label', (tester) async {
      await tester.pumpWidget(_wrap(const SocGauge(soc: 60.0)));
      expect(find.text('SOC'), findsOneWidget);
    });

    testWidgets('renders at SOC = 0 without error', (tester) async {
      await tester.pumpWidget(_wrap(const SocGauge(soc: 0.0)));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('0.0'), findsOneWidget);
    });

    testWidgets('renders at SOC = 100 without error', (tester) async {
      await tester.pumpWidget(_wrap(const SocGauge(soc: 100.0)));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('100.0'), findsOneWidget);
    });

    testWidgets('clamps negative SOC values for painter (no crash)', (tester) async {
      // The gauge clamps the value for rendering but displays raw soc text.
      await tester.pumpWidget(_wrap(const SocGauge(soc: -5.0)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('clamps SOC > 100 for painter (no crash)', (tester) async {
      await tester.pumpWidget(_wrap(const SocGauge(soc: 110.0)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('respects custom size parameter', (tester) async {
      const size = 300.0;
      await tester.pumpWidget(_wrap(const SocGauge(soc: 50.0, size: size)));

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(SocGauge),
          matching: find.byType(SizedBox),
        ).first,
      );

      expect(sizedBox.width,  size);
      expect(sizedBox.height, size);
    });

    testWidgets('uses default size when not specified', (tester) async {
      await tester.pumpWidget(_wrap(const SocGauge(soc: 50.0)));

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(SocGauge),
          matching: find.byType(SizedBox),
        ).first,
      );

      expect(sizedBox.width,  220.0);
      expect(sizedBox.height, 220.0);
    });
  });
}
