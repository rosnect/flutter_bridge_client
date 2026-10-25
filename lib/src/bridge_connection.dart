import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'bridge_payload.dart';
import 'connection_config.dart';

enum BridgeConnectionStatus { disconnected, connecting, connected }

abstract interface class BridgeConnectionHandler {
  Future<void> connect(ConnectionConfig config);
  Future<void> disconnect();
  bool get isConnected;
  Stream<BridgeConnectionStatus> get connectionChanges;
  Stream<BridgePayload> get messages;
  Future<void> send(BridgePayload payload);
}

BridgeConnectionHandler createBridgeConnectionHandler(
    BridgeTransport transport) {
  return switch (transport) {
    BridgeTransport.mqtt => MqttBridgeConnectionHandler(),
    _ => throw UnsupportedError('${transport.name} is not implemented yet.'),
  };
}

class MqttBridgeConnectionHandler implements BridgeConnectionHandler {
  final _messages = StreamController<BridgePayload>.broadcast();
  final _status = StreamController<BridgeConnectionStatus>.broadcast();
  MqttServerClient? _client;
  ConnectionConfig? _config;
  StreamSubscription<dynamic>? _updates;

  @override
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;
  @override
  Stream<BridgePayload> get messages => _messages.stream;
  @override
  Stream<BridgeConnectionStatus> get connectionChanges => _status.stream;

  @override
  Future<void> connect(ConnectionConfig config) async {
    config.validate();
    if (config.transport != BridgeTransport.mqtt) {
      throw ArgumentError('MQTT handler requires MQTT transport.');
    }
    await disconnect();
    _status.add(BridgeConnectionStatus.connecting);
    final client = MqttServerClient.withPort(
      config.host.trim(),
      config.connectionId,
      config.effectivePort,
    );
    _client = client;
    _config = config;
    client.setProtocolV311();
    client.keepAlivePeriod = 15;
    client.disconnectOnNoResponsePeriod = 20;
    client.connectTimeoutPeriod = 8000;
    client.autoReconnect = false;
    client.logging(on: false);
    client.onDisconnected = () {
      if (identical(_client, client)) {
        _status.add(BridgeConnectionStatus.disconnected);
      }
    };
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(config.connectionId)
        .startClean();
    try {
      if (config.useTls) {
        final context = SecurityContext(withTrustedRoots: true);
        if (config.caCertificate?.trim().isNotEmpty ?? false) {
          context
              .setTrustedCertificatesBytes(utf8.encode(config.caCertificate!));
        }
        if (config.clientCertificate?.trim().isNotEmpty ?? false) {
          context
              .useCertificateChainBytes(utf8.encode(config.clientCertificate!));
          context.usePrivateKeyBytes(
            utf8.encode(config.clientPrivateKey!),
            password: config.privateKeyPassword,
          );
        }
        client.secure = true;
        client.securityContext = context;
      }
      final status = await client.connect(config.username, config.password);
      if (status?.state != MqttConnectionState.connected) {
        throw StateError(
            'Broker rejected connection: ${status?.returnCode?.name}');
      }
      _updates = client.updates!.listen((events) {
        for (final event in events) {
          final message = event.payload as MqttPublishMessage;
          try {
            final json = jsonDecode(utf8.decode(message.payload.message));
            final payload = BridgePayload.fromJson(
              Map<String, Object?>.from(json as Map),
            );
            if (payload.domainId == config.domainId) _messages.add(payload);
          } on Object {
            // Ignore unrelated or malformed broker messages; keep listening.
          }
        }
      });
      client.subscribe(config.subscribeTopic, MqttQos.atLeastOnce);
      _status.add(BridgeConnectionStatus.connected);
    } on Object {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _updates?.cancel();
    _updates = null;
    final client = _client;
    _client = null;
    _config = null;
    client?.disconnect();
    _status.add(BridgeConnectionStatus.disconnected);
  }

  @override
  Future<void> send(BridgePayload payload) async {
    final config = _config;
    final client = _client;
    if (!isConnected || config == null || client == null) {
      throw StateError('MQTT broker is not connected.');
    }
    if (payload.domainId != config.domainId) {
      throw ArgumentError('Payload domain must match the connection domain.');
    }
    final builder = MqttClientPayloadBuilder()
      ..addUTF8String(jsonEncode(payload.toJson()));
    client.publishMessage(
        config.publishTopic, MqttQos.atLeastOnce, builder.payload!);
  }
}
