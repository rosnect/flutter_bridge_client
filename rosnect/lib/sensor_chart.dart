// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'sensor_presentation.dart';

const plotColors = [Color(0xffd34b49), Color(0xff17835e), Color(0xff3f6dd1)];

Color plotColorFor(String label, int fallback) => switch (label) {
      'X' => plotColors[0],
      'Y' => plotColors[1],
      'Z' => plotColors[2],
      _ => plotColors[fallback % plotColors.length],
    };

class SensorChart extends StatelessWidget {
  const SensorChart({required this.samples, required this.readings, super.key});
  final List<SensorPlotSample> samples;
  final List<SensorReading> readings;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 18, runSpacing: 6, children: [
            for (var i = 0; i < readings.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 16,
                    height: 3,
                    color: plotColorFor(readings[i].label, i)),
                const SizedBox(width: 6),
                Text(readings[i].label),
              ]),
          ]),
          const SizedBox(height: 12),
          Semantics(
              label:
                  'Time series for ${readings.map((r) => r.label).join(', ')} in ${readings.first.unit}',
              child: SizedBox(
                  height: 230,
                  width: double.infinity,
                  child: CustomPaint(
                      painter: _TimeSeriesPainter(
                    samples: samples,
                    readings: readings,
                    theme: Theme.of(context),
                  )))),
          const SizedBox(height: 4),
          Text('Time · last 30 seconds of samples',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ));
}

class _TimeSeriesPainter extends CustomPainter {
  _TimeSeriesPainter(
      {required this.samples, required this.readings, required this.theme});
  final List<SensorPlotSample> samples;
  final List<SensorReading> readings;
  final ThemeData theme;
  void label(Canvas canvas, String text, Offset origin,
      {bool right = false, bool center = false}) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(
        canvas,
        Offset(
            origin.dx -
                (right
                    ? painter.width
                    : center
                        ? painter.width / 2
                        : 0),
            origin.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty || size.width < 100) return;
    final decimals = readings.first.decimals;
    final values = [
      for (final sample in samples)
        for (final reading in readings)
          if (sample.values[reading.label]?.isFinite ?? false)
            sample.values[reading.label]!
    ];
    var low = values.isEmpty ? -1.0 : values.reduce(math.min);
    var high = values.isEmpty ? 1.0 : values.reduce(math.max);
    final padding =
        high == low ? math.max(low.abs() * .05, .1) : (high - low) * .12;
    low -= padding;
    high += padding;
    final axisLabels = [
      for (var i = 0; i <= 4; i++)
        formatSensorNumber(high - (high - low) * i / 4,
            significantDigits: 3, decimals: decimals)
    ];
    // Allow wider labels for coordinates and scientific notation.
    var left = 42.0;
    for (final text in axisLabels) {
      final painter = TextPainter(
          text: TextSpan(text: text, style: theme.textTheme.labelSmall),
          textDirection: TextDirection.ltr)
        ..layout();
      left = math.max(left, painter.width + 12);
    }
    final area = Rect.fromLTRB(left, 24, size.width - 22, size.height - 28);
    if (area.width <= 0) return;
    final end = samples.isEmpty
        ? DateTime.now().millisecondsSinceEpoch
        : samples.last.timestamp;
    final start = end - SensorHistory.windowMilliseconds;
    final grid = Paint()
      ..color = theme.colorScheme.outlineVariant.withOpacity(.6)
      ..strokeWidth = 1;
    label(canvas, readings.first.unit, const Offset(0, 0));
    for (var i = 0; i <= 4; i++) {
      final y = area.top + area.height * i / 4;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
      label(canvas, axisLabels[i], Offset(area.left - 8, y - 7), right: true);
    }
    for (var i = 0; i <= 3; i++) {
      final x = area.left + area.width * i / 3;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), grid);
      final time = DateTime.fromMillisecondsSinceEpoch(start + i * 10000);
      label(
          canvas,
          '${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
          Offset(x, area.bottom + 8),
          center: true);
    }
    canvas.save();
    canvas.clipRect(area.inflate(2));
    for (var i = 0; i < readings.length; i++) {
      final path = Path();
      Offset? previous;
      int? lastTime;
      final points = <Offset>[];
      for (final sample in samples) {
        final value = sample.values[readings[i].label];
        if (value == null || !value.isFinite || sample.timestamp < start) {
          previous = null;
          continue;
        }
        final point = Offset(
            area.left +
                (sample.timestamp - start) /
                    SensorHistory.windowMilliseconds *
                    area.width,
            area.bottom - (value - low) / (high - low) * area.height);
        if (previous == null ||
            (lastTime != null && sample.timestamp - lastTime > 3000)) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
        previous = point;
        lastTime = sample.timestamp;
        points.add(point);
      }
      final color = plotColorFor(readings[i].label, i);
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round);
      if (points.isNotEmpty) {
        canvas.drawCircle(points.last, 3, Paint()..color = color);
      }
    }
    canvas.restore();
    if (values.isEmpty) {
      label(canvas, 'Waiting for readings…', area.center - const Offset(0, 8),
          center: true);
    }
  }

  @override
  bool shouldRepaint(covariant _TimeSeriesPainter old) => true;
}
