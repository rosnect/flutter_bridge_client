import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosnect/live_sensors.dart';
import 'package:rosnect/sensor_page.dart';
import 'package:rosnect/sensor_chart.dart';
import 'package:rosnect/sensor_presentation.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';

void main() {
  test('display precision preserves small readings and coordinate detail', () {
    expect(formatSensorNumber(1.234567), '1.235');
    expect(formatSensorNumber(-0.0), '0');
    expect(formatSensorNumber(1.234567e-7), '1.235e-7');
    expect(formatSensorNumber(double.nan), '—');
    final gps =
        sensorReadings(PhoneSensorKind.location, {'latitude': 52.12345678});
    expect(gps.single.formatted, '52.123457');
    expect(formatDisplayValue({'x': 1.234567, 'y': 2.345678}),
        'x: 1.235\ny: 2.346');
    expect(formatDisplayValue('{"value":1.234567}'), 'value: 1.235');
  });
  test('history bounds memory and time and resets after a backwards clock jump',
      () {
    final history = SensorHistory();
    for (var i = 0; i < 1000; i++) {
      history
          .add(SensorPlotSample(i * 10, [SensorReading('X', i / 3, 'm/s²')]));
    }
    expect(history.samples.length, SensorHistory.maxSamples);
    history.add(SensorPlotSample(50000, const [SensorReading('X', 1, 'm/s²')]));
    expect(history.samples.length, 1);
    history.add(SensorPlotSample(40000, const [SensorReading('X', 2, 'm/s²')]));
    expect(history.samples.length, 1);
    expect(history.samples.single.values['X'], 2);
  });
  testWidgets(
      'two-column tiles hide data; switch does not open details; tapping reveals XYZ graph',
      (tester) async {
    final session = ConnectionSession();
    final live = LiveSensors(session);
    addTearDown(() {
      live.dispose();
      session.dispose();
    });
    live.available[PhoneSensorKind.accelerometer] = true;
    live.latest[PhoneSensorKind.accelerometer] = [1.234567, 2.345678, 9.876543];
    final history = SensorHistory();
    history.add(SensorPlotSample(
        10000,
        sensorReadings(PhoneSensorKind.accelerometer,
            live.latest[PhoneSensorKind.accelerometer])));
    live.history[PhoneSensorKind.accelerometer] = history;
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: SensorPage(live: live))));
    final acceleration =
        find.byKey(const ValueKey('sensor-tile-accelerometer'));
    final gyro = find.byKey(const ValueKey('sensor-tile-gyroscope'));
    expect(tester.getTopLeft(acceleration).dy, tester.getTopLeft(gyro).dy);
    expect(tester.getTopLeft(gyro).dx,
        greaterThan(tester.getTopLeft(acceleration).dx));
    expect(find.byType(SensorChart), findsNothing);
    expect(find.text('Latest readings'), findsNothing);
    expect(find.text('1.235'), findsNothing);
    await tester
        .tap(find.descendant(of: acceleration, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(live.sensors[PhoneSensorKind.accelerometer]!.enabled, true);
    expect(find.byType(SensorDetailPage), findsNothing);
    await tester.tap(find.text('Accelerometer'));
    await tester.pumpAndSettle();
    expect(find.byType(SensorChart), findsOneWidget);
    expect(find.text('Latest readings'), findsOneWidget);
    await tester.ensureVisible(find.text('Latest readings'));
    await tester.pumpAndSettle();
    expect(find.text('1.235'), findsOneWidget);
    expect(find.text('X'), findsWidgets);
    expect(find.text('Y'), findsWidgets);
    expect(find.text('Z'), findsWidgets);
    expect(find.text('Identifier (submit to apply)'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(live.sensors[PhoneSensorKind.accelerometer]!.enabled, true);
  });
  testWidgets('phone-width tiles and detail graph fit without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = ConnectionSession();
    final live = LiveSensors(session);
    addTearDown(() {
      live.dispose();
      session.dispose();
    });
    live.latest[PhoneSensorKind.magnetometer] = [0.000001, 23.456789, -45.6789];
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: SensorPage(live: live))));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Magnetometer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SensorChart), findsOneWidget);
  });
  testWidgets(
      'axis toggles support pairs, isolation, none and all with consistent colors',
      (tester) async {
    final session = ConnectionSession();
    final live = LiveSensors(session);
    addTearDown(() {
      live.dispose();
      session.dispose();
    });
    live.latest[PhoneSensorKind.accelerometer] = [1.0, 2.0, 3.0];
    await tester.pumpWidget(MaterialApp(
        home:
            SensorDetailPage(live: live, kind: PhoneSensorKind.accelerometer)));
    List<String> axes() => tester
        .widget<SensorChart>(find.byType(SensorChart))
        .readings
        .map((r) => r.label)
        .toList();
    expect(axes(), ['X', 'Y', 'Z']);
    final zColor = plotColorFor('Z', 2);
    await tester.tap(find.byKey(const ValueKey('axis-toggle-Y')));
    await tester.pump();
    expect(axes(), ['X', 'Z']);
    await tester.tap(find.byKey(const ValueKey('axis-toggle-X')));
    await tester.pump();
    expect(axes(), ['Z']);
    expect(plotColorFor('Z', 0), zColor);
    await tester.tap(find.byKey(const ValueKey('axis-toggle-Z')));
    await tester.pump();
    expect(find.byType(SensorChart), findsNothing);
    expect(find.text('Select an axis to show its graph.'), findsOneWidget);
    await tester.tap(find.text('All axes'));
    await tester.pump();
    expect(axes(), ['X', 'Y', 'Z']);
  });
}
