import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosnect/main.dart';

void main() {
  testWidgets('Rosnect has laptop defaults and TLS certificate controls',
      (tester) async {
    await tester.pumpWidget(const RosnectApp());
    await tester.pumpAndSettle();
    expect(find.text('rosnect'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '192.168.0.81');
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Normal · 1883'), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSL / TLS · 8883').last);
    await tester.pumpAndSettle();
    expect(find.text('CA certificate PEM (optional)'), findsOneWidget);
    await tester.ensureVisible(find.text('Client certificate (mutual TLS)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Client certificate (mutual TLS)'));
    await tester.pumpAndSettle();
    expect(find.text('Client certificate PEM'), findsOneWidget);
    expect(find.text('Client private key PEM'), findsOneWidget);
  });
  testWidgets('tab switching preserves broker input', (tester) async {
    await tester.pumpWidget(const RosnectApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'my-broker.local');
    await tester.tap(find.text('Sensors').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connections').last);
    await tester.pumpAndSettle();
    expect(find.text('my-broker.local'), findsOneWidget);
  });
}
