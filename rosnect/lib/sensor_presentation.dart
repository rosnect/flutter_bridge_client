// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'dart:collection';
import 'dart:convert';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';

String formatSensorNumber(num value,
    {int significantDigits = 4, int? decimals}) {
  if (!value.isFinite) return '—';
  if (value == 0) return decimals == null ? '0' : 0.toStringAsFixed(decimals);
  if (decimals != null) return value.toStringAsFixed(decimals);
  final parts = value.toStringAsPrecision(significantDigits).split('e');
  var mantissa = parts.first;
  if (mantissa.contains('.')) {
    mantissa = mantissa
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return parts.length == 1 ? mantissa : '${mantissa}e${int.parse(parts.last)}';
}

/// Display formatting only; outgoing sensor values retain their original precision.
String formatDisplayValue(Object? value) {
  if (value == null) return '—';
  if (value is double) return formatSensorNumber(value);
  if (value is Map) {
    return value.entries
        .map((e) => '${e.key}: ${formatDisplayValue(e.value)}')
        .join('\n');
  }
  if (value is List) {
    final items = value.take(16).map(formatDisplayValue).join(', ');
    return '[$items${value.length > 16 ? ', … (${value.length} values)' : ''}]';
  }
  if (value is String) {
    try {
      final parsed = jsonDecode(value);
      if (parsed is Map || parsed is List) return formatDisplayValue(parsed);
    } on FormatException {/* Ordinary text. */}
  }
  return '$value';
}

class SensorReading {
  const SensorReading(this.label, this.value, this.unit, {this.decimals});
  final String label;
  final double value;
  final String unit;
  final int? decimals;
  String get formatted => formatSensorNumber(value, decimals: decimals);
}

List<SensorReading> sensorReadings(PhoneSensorKind kind, Object? raw) {
  if (raw == null) return const [];
  if (kind == PhoneSensorKind.camera) {
    if (raw is List<int>) {
      return [SensorReading('JPEG size', raw.length / 1024, 'KiB')];
    }
    return const [];
  }
  if (raw is List) {
    final unit = switch (kind) {
      PhoneSensorKind.accelerometer => 'm/s²',
      PhoneSensorKind.gyroscope => 'rad/s',
      PhoneSensorKind.magnetometer => 'µT',
      PhoneSensorKind.light => 'lx',
      PhoneSensorKind.barometer => 'hPa',
      _ => '',
    };
    final labels = switch (kind) {
      PhoneSensorKind.light => ['Illuminance'],
      PhoneSensorKind.barometer => ['Pressure'],
      _ => ['X', 'Y', 'Z'],
    };
    return [
      for (var i = 0; i < labels.length && i < raw.length; i++)
        if (raw[i] is num && (raw[i] as num).isFinite)
          SensorReading(labels[i], (raw[i] as num).toDouble(), unit)
    ];
  }
  if (raw is! Map) return const [];
  SensorReading? read(String key, String label, String unit,
      {double scale = 1, int? decimals}) {
    final value = raw[key];
    return value is num && value.isFinite
        ? SensorReading(label, value.toDouble() * scale, unit,
            decimals: decimals)
        : null;
  }

  final readings = switch (kind) {
    PhoneSensorKind.location => [
        read('latitude', 'Latitude', '°', decimals: 6),
        read('longitude', 'Longitude', '°', decimals: 6),
        read('altitude', 'Altitude', 'm'),
        read('accuracy', 'Accuracy', 'm'),
        read('speed', 'Speed', 'm/s'),
      ],
    PhoneSensorKind.battery => [
        if ((raw['percentage'] as num? ?? -1) >= 0)
          read('percentage', 'Battery', '%', scale: 100),
        read('voltage', 'Voltage', 'V'),
        read('temperature', 'Temperature', '°C'),
      ],
    PhoneSensorKind.microphone => [
        read('dbfs', 'Level', 'dBFS'),
        read('rms', 'RMS', 'full scale')
      ],
    PhoneSensorKind.touch => [
        read('x', 'X', 'normalized'),
        read('y', 'Y', 'normalized')
      ],
    _ => <SensorReading?>[],
  };
  return readings.whereType<SensorReading>().toList();
}

class SensorPlotSample {
  SensorPlotSample(this.timestamp, Iterable<SensorReading> readings)
      : values = {for (final reading in readings) reading.label: reading.value};
  final int timestamp;
  final Map<String, double> values;
}

/// Fixed memory and time bounds, including fast touch streams and clock changes.
class SensorHistory {
  static const windowMilliseconds = 30000;
  static const maxSamples = 600;
  final Queue<SensorPlotSample> _samples = Queue();
  List<SensorPlotSample> get samples => List.unmodifiable(_samples);
  void add(SensorPlotSample sample) {
    if (sample.values.isEmpty) return;
    if (_samples.isNotEmpty && sample.timestamp < _samples.last.timestamp) {
      _samples.clear();
    }
    _samples.addLast(sample);
    while (_samples.length > maxSamples ||
        (_samples.isNotEmpty &&
            sample.timestamp - _samples.first.timestamp > windowMilliseconds)) {
      _samples.removeFirst();
    }
  }
}
