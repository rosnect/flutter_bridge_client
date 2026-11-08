// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosnect/main.dart';

void main() {
  testWidgets('appearance toggle persists and applies across all pages',
      (tester) async {
    var stored = 'light';
    const channel = MethodChannel('rosnect/preferences');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'getTheme') return stored;
      if (call.method == 'setTheme') stored = call.arguments as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const RosnectApp());
    await tester.pumpAndSettle();
    Brightness brightness() =>
        Theme.of(tester.element(find.text('rosnect'))).brightness;
    expect(brightness(), Brightness.light);
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(stored, 'dark');
    for (final tab in ['Sensors', 'Subscribe', 'Connections']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const RosnectApp());
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(stored, 'light');
  });
  testWidgets('subscription tiles keep received data behind a tap',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const RosnectApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscribe').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add subscription'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add subscription'));
    await tester.pumpAndSettle();
    expect(find.text('Connect first'), findsNothing);
    await tester.ensureVisible(find.text('robot.status').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('robot.status').last);
    await tester.pumpAndSettle();
    expect(find.text('Connect first'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
