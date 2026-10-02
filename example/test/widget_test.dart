import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_zpl_printer_example/main.dart';

void main() {
  testWidgets('shows one tab per transport', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('Bluetooth'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.text('USB'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });
}
