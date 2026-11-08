// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'bridge_payload.dart';
import 'connection_config.dart';

/// Broker connection states, separate from interface-configuration readiness.
enum BridgeConnectionStatus { disconnected, connecting, connected }

/// Transport interface used by [BridgeClient] and custom implementations.
abstract interface class BridgeConnectionHandler {
  /// Opens a connection after validating [config].
  Future<void> connect(ConnectionConfig config);

  /// Disconnects and releases transport resources.
  Future<void> disconnect();

  /// Whether the transport is connected.
  bool get isConnected;

  /// Broadcast transport-state notifications.
  Stream<BridgeConnectionStatus> get connectionChanges;

  /// Broadcast decoded payloads received from the transport.
  Stream<BridgePayload> get messages;

  /// Sends an application payload; transport delivery is not ROS execution acknowledgement.
  Future<void> send(BridgePayload payload);
}

/// Creates the selected transport; only MQTT is currently implemented.
BridgeConnectionHandler createBridgeConnectionHandler(
    BridgeTransport transport) {
  return switch (transport) {
    BridgeTransport.mqtt => MqttBridgeConnectionHandler(),
    _ => throw UnsupportedError('${transport.name} is not implemented yet.'),
  };
}

/// Optional full-snapshot interface-discovery channel for a transport.
abstract interface class BridgeConfigurationChannel {
  /// Host configuration requests and acknowledgements.
  Stream<Map<String, Object?>> get configurationMessages;

  /// Publishes an entire desired interface snapshot, not a patch.
  Future<void> sendConfiguration(Map<String, Object?> snapshot);
}

/// MQTT 3.1.1 JSON transport with verified TLS and device configuration.
///
/// Data is sent at QoS 0 without retention. Configuration uses QoS 1 and
/// retention. Reconnection is explicit; only one device should own a connection ID.
class MqttBridgeConnectionHandler
    implements BridgeConnectionHandler, BridgeConfigurationChannel {
  final _control = StreamController<Map<String, Object?>>.broadcast();
  @override
  Stream<Map<String, Object?>> get configurationMessages => _control.stream;
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
            if (event.topic ==
                    '${config.baseTopic}/${config.domainId}/${config.connectionId}/config_status' ||
                event.topic ==
                    '${config.baseTopic}/${config.domainId}/${config.connectionId}/config_request') {
              final control = Map<String, Object?>.from(json as Map);
              control['_control'] = event.topic.split('/').last;
              _control.add(control);
              continue;
            }
            final payload = BridgePayload.fromJson(
              Map<String, Object?>.from(json as Map),
            );
            if (payload.domainId == config.domainId) _messages.add(payload);
          } on Object {
            // Ignore unrelated or malformed broker messages; keep listening.
          }
        }
      });
      final topics = {
        config.subscribeTopic,
        '${config.baseTopic}/${config.domainId}/${config.connectionId}/config_status',
        '${config.baseTopic}/${config.domainId}/${config.connectionId}/config_request'
      };
      final subscribed = Completer<void>();
      final remaining = {...topics};
      client.onSubscribed = (topic) {
        remaining.remove(topic);
        if (remaining.isEmpty && !subscribed.isCompleted) subscribed.complete();
      };
      client.onSubscribeFail = (topic) {
        if (!subscribed.isCompleted) {
          subscribed.completeError(StateError('Broker denied $topic'));
        }
      };
      for (final topic in topics) {
        client.subscribe(topic, MqttQos.atLeastOnce);
      }
      await subscribed.future.timeout(const Duration(seconds: 8));
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
  Future<void> sendConfiguration(Map<String, Object?> snapshot) async {
    final config = _config;
    if (!isConnected || config == null) throw StateError('Broker disconnected');
    final builder = MqttClientPayloadBuilder()
      ..addUTF8String(jsonEncode(snapshot));
    _client!.publishMessage(
        '${config.baseTopic}/${config.domainId}/${config.connectionId}/config',
        MqttQos.atLeastOnce,
        builder.payload!,
        retain: true);
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
        config.publishTopic, MqttQos.atMostOnce, builder.payload!);
  }
}
