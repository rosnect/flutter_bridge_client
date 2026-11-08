// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';
import 'live_sensors.dart';
import 'sensor_chart.dart';
import 'sensor_presentation.dart';
import 'rosnect_style.dart';

String sensorStatus(LiveSensors live, PhoneSensorKind kind) {
  if (!(live.available[kind] ?? false)) return 'Unavailable';
  if (live.errors.containsKey(kind)) return 'Needs attention';
  if (!live.sensors[kind]!.enabled) return 'Off';
  if (!live.session.isConnected) return 'Connect to stream';
  if (!live.interfaces.ready) return 'Setting up…';
  return 'Live';
}

class SensorPage extends StatelessWidget {
  const SensorPage({required this.live, super.key});
  final LiveSensors live;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: live,
      builder: (context, _) => CustomScrollView(slivers: [
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                sliver: SliverToBoxAdapter(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeading(
                        index: '02',
                        title: 'sensors',
                        subtitle: 'Switch on to share. Tap a tile to explore.'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.circle,
                          size: 9,
                          color: live.interfaces.ready
                              ? Colors.green
                              : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              !live.session.isConnected
                                  ? 'Connect to your broker to start'
                                  : live.interfaces.ready
                                      ? 'ROS interfaces ready'
                                      : 'Waiting for ROS interfaces…',
                              style: Theme.of(context).textTheme.labelMedium)),
                      IconButton(
                          tooltip: 'Retry ROS setup',
                          onPressed: live.session.isConnected
                              ? live.interfaces.resync
                              : null,
                          icon: const Icon(Icons.sync)),
                      IconButton(
                          tooltip: 'App permissions',
                          onPressed: live.settings,
                          icon: const Icon(Icons.settings_outlined)),
                    ]),
                    if (live.interfaces.error != null)
                      Text(live.interfaces.error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    if (live.globalError != null)
                      Text(live.globalError!,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ))),
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 184 +
                          (MediaQuery.textScalerOf(context).scale(14) - 14) *
                              5),
                  delegate: SliverChildListDelegate([
                    for (final item in live.sensors.values)
                      _SensorTile(live: live, item: item)
                  ]),
                )),
          ]));
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({required this.live, required this.item});
  final LiveSensors live;
  final EnabledPhoneSensor item;
  @override
  Widget build(BuildContext context) {
    final kind = item.definition.kind;
    final colors = Theme.of(context).colorScheme;
    final active = item.enabled;
    final status = sensorStatus(live, kind);
    return Material(
        key: ValueKey('sensor-tile-${kind.name}'),
        color: active
            ? colors.primaryContainer.withOpacity(.55)
            : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
                color: active
                    ? colors.primary.withOpacity(.3)
                    : colors.outlineVariant)),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SensorDetailPage(live: live, kind: kind))),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RosnectGlyph(kind.name,
                              color: active
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              size: 30),
                          SizedBox(
                              width: 50,
                              height: 40,
                              child: FittedBox(
                                  child: Semantics(
                                      label: '${item.definition.name} sharing',
                                      child: Switch(
                                          value: active,
                                          onChanged:
                                              live.available[kind] == true
                                                  ? (value) =>
                                                      live.enable(kind, value)
                                                  : null)))),
                        ]),
                    const SizedBox(height: 12),
                    Text(item.definition.name,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(children: [
                      Icon(Icons.circle,
                          size: 7,
                          color: live.errors.containsKey(kind)
                              ? colors.error
                              : status == 'Live'
                                  ? Colors.green
                                  : colors.outline),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(status,
                              style: Theme.of(context).textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ]),
                  ])),
        ));
  }
}

class SensorDetailPage extends StatefulWidget {
  const SensorDetailPage({required this.live, required this.kind, super.key});
  final LiveSensors live;
  final PhoneSensorKind kind;
  @override
  State<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends State<SensorDetailPage> {
  String? _measurement;
  final Set<String> _hiddenAxes = {};
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.live,
      builder: (context, _) {
        final live = widget.live;
        final kind = widget.kind;
        final item = live.sensors[kind]!;
        final samples =
            live.history[kind]?.samples ?? const <SensorPlotSample>[];
        final readings = sensorReadings(
            kind,
            kind == PhoneSensorKind.camera
                ? live.cameraPreview
                : live.latest[kind]);
        final multiAxis = [
          PhoneSensorKind.accelerometer,
          PhoneSensorKind.gyroscope,
          PhoneSensorKind.magnetometer,
          PhoneSensorKind.touch
        ].contains(kind);
        final selected = readings.any((r) => r.label == _measurement)
            ? _measurement
            : readings.firstOrNull?.label;
        final plotted = multiAxis
            ? readings.where((r) => !_hiddenAxes.contains(r.label)).toList()
            : readings.where((r) => r.label == selected).toList();
        final visibleReadings = multiAxis ? plotted : readings;
        final topic = live.interfaces.topicFor(item.identifier);
        final colors = Theme.of(context).colorScheme;
        return Scaffold(
            appBar: AppBar(
                title: Text(item.definition.name.toLowerCase()),
                actions: const [ThemeToggle(), SizedBox(width: 8)]),
            body: SafeArea(
                child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                    child: SwitchListTile(
                        title: Text(sensorStatus(live, kind)),
                        subtitle: Text(item.definition.description),
                        value: item.enabled,
                        onChanged: live.available[kind] == true
                            ? (v) => live.enable(kind, v)
                            : null)),
                if (live.errors[kind] != null)
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(live.errors[kind]!,
                          style: TextStyle(color: colors.error))),
                if (!item.enabled)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child:
                          Text('Turn this sensor on to stream new readings.')),
                if (kind == PhoneSensorKind.camera) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: ColoredBox(
                              color: Colors.black,
                              child: live.cameraPreview == null
                                  ? const Center(
                                      child: Text(
                                          'Camera preview appears when streaming',
                                          style:
                                              TextStyle(color: Colors.white70)))
                                  : Image.memory(live.cameraPreview!,
                                      gaplessPlayback: true,
                                      fit: BoxFit.contain)))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<bool>(
                            value: live.frontCamera,
                            decoration:
                                const InputDecoration(labelText: 'Camera'),
                            items: const [
                              DropdownMenuItem(
                                  value: false, child: Text('Rear')),
                              DropdownMenuItem(
                                  value: true, child: Text('Front'))
                            ],
                            onChanged: item.enabled
                                ? (v) => live.cameraOptions(front: v)
                                : null)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: DropdownButtonFormField<int>(
                            value: live.cameraFps,
                            decoration:
                                const InputDecoration(labelText: 'Frame rate'),
                            items: [
                              for (final n in [1, 2, 5])
                                DropdownMenuItem(
                                    value: n, child: Text('$n FPS'))
                            ],
                            onChanged: item.enabled
                                ? (v) => live.cameraOptions(fps: v)
                                : null)),
                  ]),
                ],
                if (kind != PhoneSensorKind.camera) ...[
                  const SizedBox(height: 16),
                  Text('Live graph',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (multiAxis) ...[
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final axis in (kind == PhoneSensorKind.touch
                          ? ['X', 'Y']
                          : ['X', 'Y', 'Z']))
                        FilterChip(
                            key: ValueKey('axis-toggle-$axis'),
                            label: Text(axis),
                            avatar: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: plotColorFor(axis, 0))),
                            selected: !_hiddenAxes.contains(axis),
                            onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _hiddenAxes.remove(axis);
                                  } else {
                                    _hiddenAxes.add(axis);
                                  }
                                })),
                      TextButton(
                          onPressed: () => setState(_hiddenAxes.clear),
                          child: const Text('All axes')),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  if (!multiAxis && readings.length > 1) ...[
                    DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selected,
                        decoration:
                            const InputDecoration(labelText: 'Measurement'),
                        items: [
                          for (final reading in readings)
                            DropdownMenuItem(
                                value: reading.label,
                                child:
                                    Text('${reading.label} (${reading.unit})'))
                        ],
                        onChanged: (value) =>
                            setState(() => _measurement = value)),
                    const SizedBox(height: 16),
                  ],
                  if (plotted.isEmpty)
                    Container(
                        height: 230,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(24)),
                        child: Text(multiAxis && readings.isNotEmpty
                            ? 'Select an axis to show its graph.'
                            : 'Waiting for sensor readings…'))
                  else
                    SensorChart(samples: samples, readings: plotted),
                ],
                const SizedBox(height: 20),
                Text('Latest readings',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (visibleReadings.isEmpty)
                  Text(readings.isEmpty
                      ? 'No readings yet.'
                      : 'All axes hidden. Select an axis above.'),
                if (visibleReadings.isNotEmpty)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Column(children: [
                            for (var i = 0; i < visibleReadings.length; i++)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(children: [
                                    if (multiAxis) ...[
                                      Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: plotColorFor(
                                                  visibleReadings[i].label,
                                                  i))),
                                      const SizedBox(width: 8)
                                    ],
                                    Expanded(
                                        child: Text(visibleReadings[i].label)),
                                    Text(visibleReadings[i].formatted,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(width: 8),
                                    Text(visibleReadings[i].unit,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ])),
                          ]))),
                Text(
                    '${live.sent[kind] ?? 0} samples sent${live.lastSampleTime[kind] == null ? '' : ' · Last sample ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(live.lastSampleTime[kind]!)).format(context)}'}',
                    style: Theme.of(context).textTheme.labelSmall),
                if (kind == PhoneSensorKind.touch && item.enabled) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                      height: 160,
                      child: LayoutBuilder(
                          builder: (context, constraints) => GestureDetector(
                              onPanStart: (e) => live.touch(
                                  e.localPosition, constraints.biggest, 'down'),
                              onPanUpdate: (e) => live.touch(
                                  e.localPosition, constraints.biggest, 'move'),
                              onPanEnd: (_) => live.touch(
                                  Offset.zero, constraints.biggest, 'up'),
                              onTapDown: (e) => live.touch(
                                  e.localPosition, constraints.biggest, 'tap'),
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: colors.secondaryContainer,
                                      borderRadius: BorderRadius.circular(24)),
                                  alignment: Alignment.center,
                                  child: const Text('Touch or drag here'))))),
                ],
                const SizedBox(height: 16),
                ExpansionTile(
                    title: const Text('Sensor settings'),
                    childrenPadding: const EdgeInsets.all(12),
                    children: [
                      TextFormField(
                          initialValue: item.identifier,
                          decoration: const InputDecoration(
                              labelText: 'Identifier (submit to apply)'),
                          onFieldSubmitted: (value) =>
                              live.rename(kind, value.trim())),
                      const SizedBox(height: 12),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('ROS message type'),
                          subtitle: Text(sensorMessageTypes[kind]!)),
                      if (topic != null)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('ROS topic'),
                            subtitle: SelectableText(topic)),
                    ]),
              ],
            )));
      });
}
