// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';

void main() => runApp(const MaterialApp(home: BridgeExample()));

/// A minimal device-owned MQTT interface with a publish and subscribe binding.
class BridgeExample extends StatefulWidget {
  const BridgeExample({super.key});

  @override
  State<BridgeExample> createState() => _BridgeExampleState();
}

class _BridgeExampleState extends State<BridgeExample> {
  final _session = ConnectionSession();
  late final DeviceInterfaces _interfaces = DeviceInterfaces(_session);
  final _host = TextEditingController(text: 'localhost');
  final _identity = TextEditingController(text: 'flutter_demo');
  StreamSubscription<BridgePayload>? _commands;
  String _received = 'No command received';
  String? _error;

  @override
  void initState() {
    super.initState();
    _session.addListener(_refresh);
    _interfaces.addListener(_refresh);
    _interfaces.update(const [
      {
        'identifier': 'device.status',
        'direction': 'DEVICE_TO_ROS',
        'value_type': 'STRING',
        'ros_topic': 'device_status',
      },
      {
        'identifier': 'robot.command',
        'direction': 'ROS_TO_DEVICE',
        'value_type': 'STRING',
        'ros_topic': 'robot_command',
      },
    ]);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    try {
      await _commands?.cancel();
      await _session.connect(ConnectionConfig(
        connectionId: _identity.text.trim(),
        domainId: 7,
        transport: BridgeTransport.mqtt,
        host: _host.text.trim(),
      ));
      if (_session.isConnected) {
        _commands =
            _session.client!.subscribe('robot.command').listen((payload) {
          if (mounted) setState(() => _received = '${payload.value}');
        });
      }
      if (mounted) setState(() => _error = _session.error);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _publish() async {
    try {
      await _session.client!.writeData('device.status', 'Hello from Flutter');
      if (mounted) setState(() => _error = null);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  void dispose() {
    _session.removeListener(_refresh);
    _interfaces.removeListener(_refresh);
    unawaited(_commands?.cancel());
    _interfaces.dispose();
    _session.dispose();
    _host.dispose();
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Rosnect bridge example')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          TextField(
              controller: _host,
              decoration: const InputDecoration(
                  labelText: 'MQTT broker hostname / IP')),
          TextField(
              controller: _identity,
              decoration:
                  const InputDecoration(labelText: 'Unique connection ID')),
          const SizedBox(height: 16),
          Text(_session.isConnected
              ? 'Broker connected'
              : 'Broker disconnected'),
          Text(_interfaces.ready
              ? 'ROS interfaces acknowledged'
              : 'Waiting for ROS interface acknowledgement'),
          if (_interfaces.rosNamespace.isNotEmpty)
            Text(_interfaces.rosNamespace),
          if (_error != null) Text(_error!),
          if (_interfaces.error != null) Text(_interfaces.error!),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _session.busy ? null : _connect,
              child: const Text('Connect / reconnect')),
          OutlinedButton(
              onPressed: _session.busy || !_session.isConnected
                  ? null
                  : _session.disconnect,
              child: const Text('Disconnect')),
          ElevatedButton(
              onPressed:
                  _interfaces.ready && _session.isConnected ? _publish : null,
              child: const Text('Publish status')),
          const SizedBox(height: 16),
          Text('Latest robot.command: $_received'),
        ]),
      );
}
