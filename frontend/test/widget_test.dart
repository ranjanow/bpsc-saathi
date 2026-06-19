// Basic smoke test for BPSC Saathi.
//
// Verifies the app launches without crashing.

import 'package:flutter_test/flutter_test.dart';

import 'package:bpsc_engine_frontend/main.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const BpscEngineApp());

    // The dashboard should render with the greeting
    expect(find.textContaining('Welcome'), findsOneWidget);
  });
}
