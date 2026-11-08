// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';
import 'domain_guard_test.dart' show FakeHandler, config;

class ConfigHandler extends FakeHandler implements BridgeConfigurationChannel {
  final control = StreamController<Map<String, Object?>>.broadcast();
  final snapshots = <Map<String, Object?>>[];
  @override
  Stream<Map<String, Object?>> get configurationMessages => control.stream;
  @override
  Future<void> sendConfiguration(Map<String, Object?> snapshot) async {
    snapshots.add(
        Map<String, Object?>.from(jsonDecode(jsonEncode(snapshot)) as Map));
  }

  void ack(Map<String, Object?> snapshot,
      {bool accepted = true, int domain = 7}) {
    control.add({
      ...snapshot,
      '_control': 'config_status',
      'domain_id': domain,
      'accepted': accepted,
      'error': accepted ? '' : 'unsupported schema',
      'ros_namespace': '/test'
    });
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
const binding = <String, Object?>{
  'identifier': 'phone.light',
  'direction': 'DEVICE_TO_ROS',
  'value_type': 'JSON',
  'ros_topic': 'light',
  'ros_message_type': 'sensor_msgs/msg/Illuminance'
};
void main() {
  test(
      'readiness requires matching domain/ID ACK and coalesces pending changes',
      () async {
    final handler = ConfigHandler();
    final session = ConnectionSession(factory: (_) => handler);
    final interfaces = DeviceInterfaces(session);
    await session.connect(config());
    await tick();
    final initial = handler.snapshots.single;
    interfaces.update([binding]);
    expect(handler.snapshots.length, 1);
    handler.ack(initial, domain: 8);
    await tick();
    expect(interfaces.ready, false);
    handler.ack(initial);
    await tick();
    expect(handler.snapshots.length, 2);
    final changed = handler.snapshots.last;
    expect(changed['configuration_id'], isNot(initial['configuration_id']));
    expect(changed['bindings'], [binding]);
    expect(interfaces.ready, false);
    handler.ack(changed);
    await tick();
    expect(interfaces.ready, true);
    expect(interfaces.topicFor('phone.light'), '/test/light');
    await session.disconnect();
    expect(interfaces.ready, false);
    interfaces.dispose();
    session.dispose();
  });
  test('rejection restores the accepted retained config and surfaces the error',
      () async {
    final handler = ConfigHandler();
    final session = ConnectionSession(factory: (_) => handler);
    final interfaces = DeviceInterfaces(session);
    await session.connect(config());
    await tick();
    final accepted = handler.snapshots.single;
    handler.ack(accepted);
    await tick();
    interfaces.update([binding]);
    handler.ack(handler.snapshots.last, accepted: false);
    await tick();
    expect(interfaces.ready, false);
    expect(interfaces.error, contains('unsupported schema'));
    expect(handler.snapshots.last['configuration_id'],
        accepted['configuration_id']);
    interfaces.dispose();
    session.dispose();
  });
  test('host config requests resend the same snapshot', () async {
    final handler = ConfigHandler();
    final session = ConnectionSession(factory: (_) => handler);
    final interfaces = DeviceInterfaces(session);
    await session.connect(config());
    await tick();
    final snapshot = handler.snapshots.single;
    handler.control.add({
      '_control': 'config_request',
      'schema_version': 1,
      'connection_id': 'phone',
      'domain_id': 7,
      'config_encoding': 'json',
      'payload_encoding': 'json'
    });
    await tick();
    expect(handler.snapshots.length, 2);
    expect(handler.snapshots.last, snapshot);
    interfaces.dispose();
    session.dispose();
  });
}
