import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_ota_update_example/main.dart';

void main() {
  testWidgets('shows the check button', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(
      find.widgetWithText(FilledButton, 'Check for updates'),
      findsOneWidget,
    );
  });
}
