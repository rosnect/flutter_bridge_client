import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:ros2_embedded_bridge_client/src/bridge_client.dart';
import 'package:ros2_embedded_bridge_client/src/bridge_connection.dart';
import 'package:ros2_embedded_bridge_client/src/bridge_payload.dart';
import 'package:ros2_embedded_bridge_client/src/connection_config.dart';

Future<void> main(List<String> args) async {
  final host = args.isEmpty ? '192.168.0.81' : args.first;
  final tls = args.contains('--tls');
  final config = ConnectionConfig(
      connectionId: 'rosnect_smoke',
      domainId: 7,
      transport: BridgeTransport.mqtt,
      host: host,
      port: tls ? 18884 : 1883,
      useTls: tls,
      caCertificate:
          tls ? await readCa(args[args.indexOf('--tls') + 1]) : null);
  final peer = MqttServerClient.withPort(
      host, 'rosnect_test_peer', config.effectivePort);
  // This peer uses the normal broker for the non-TLS round trip below.
  if (tls) {
    final client = BridgeClient(MqttBridgeConnectionHandler());
    try {
      await client.connect(config);
      if (!client.isConnected) throw StateError('TLS connection failed');
      print('PASS: verified TLS broker connection');
    } finally {
      await client.disconnect();
    }
    return;
  }
  peer.setProtocolV311();
  peer.logging(on: false);
  final client = BridgeClient(MqttBridgeConnectionHandler());
  try {
    await peer.connect();
    peer.subscribe(config.publishTopic, MqttQos.atLeastOnce);
    final outgoing = peer.updates!.first.timeout(const Duration(seconds: 5));
    await client.connect(config);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await client.writeData('phone.test', {'value': 42});
    final event = (await outgoing).single.payload as MqttPublishMessage;
    final json = jsonDecode(utf8.decode(event.payload.message));
    if (json['identifier'] != 'phone.test' || json['domain_id'] != 7) {
      throw StateError('Wrong outgoing envelope');
    }
    final received = client
        .subscribe('robot.status')
        .first
        .timeout(const Duration(seconds: 5));
    final builder = MqttClientPayloadBuilder()
      ..addUTF8String(jsonEncode(const BridgePayload(
              identifier: 'robot.status',
              domainId: 7,
              valueType: BridgeValueType.string,
              value: 'ready')
          .toJson()));
    peer.publishMessage(
        config.subscribeTopic, MqttQos.atLeastOnce, builder.payload!);
    if ((await received).value != 'ready') throw StateError('Wrong reply');
    print('PASS: real broker connect, publish, receive and domain envelope');
  } finally {
    await client.disconnect();
    peer.disconnect();
  }
}

Future<String> readCa(String path) async => File(path).readAsString();
