import 'dart:async';

import 'bridge_payload.dart';
import 'connection_config.dart';

typedef PayloadListener = void Function(BridgePayload payload);

abstract interface class BridgeConnectionHandler {
  Future<void> connect(ConnectionConfig config);
  Future<void> disconnect();
  bool get isConnected;
  Stream<BridgePayload> get messages;
  Future<void> send(BridgePayload payload);
}

BridgeConnectionHandler createBridgeConnectionHandler(
    BridgeTransport transport) {
  return switch (transport) {
    BridgeTransport.mqtt => MqttBridgeConnectionHandler(),
    BridgeTransport.websocket => WebSocketBridgeConnectionHandler(),
    BridgeTransport.redis => RedisBridgeConnectionHandler(),
  };
}

abstract class GuardedBridgeConnectionHandler
    implements BridgeConnectionHandler {
  ConnectionConfig? _config;

  ConnectionConfig get config {
    final current = _config;
    if (current == null) {
      throw StateError('Connection handler is not connected');
    }
    return current;
  }

  @override
  Future<void> connect(ConnectionConfig config) async {
    config.validate();
    _config = config;
    await open(config);
  }

  @override
  Future<void> send(BridgePayload payload) {
    if (payload.domainId != config.domainId) {
      throw ArgumentError.value(
        payload.domainId,
        'payload.domainId',
        'must match connection domainId ${config.domainId}',
      );
    }
    return sendChecked(payload);
  }

  Future<void> open(ConnectionConfig config);
  Future<void> sendChecked(BridgePayload payload);
}

class MqttBridgeConnectionHandler extends GuardedBridgeConnectionHandler {
  final _controller = StreamControllerAdapter();
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<BridgePayload> get messages => _controller.stream;

  @override
  Future<void> open(ConnectionConfig config) async {
    if (config.transport != BridgeTransport.mqtt) {
      throw ArgumentError(
          'MqttBridgeConnectionHandler requires mqtt transport');
    }
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> sendChecked(BridgePayload payload) async {
    if (!_connected) {
      throw StateError('MQTT bridge is not connected');
    }
    // TODO: Wire this to mqtt_client or another chosen MQTT package.
  }
}

class WebSocketBridgeConnectionHandler extends GuardedBridgeConnectionHandler {
  final _controller = StreamControllerAdapter();
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<BridgePayload> get messages => _controller.stream;

  @override
  Future<void> open(ConnectionConfig config) async {
    if (config.transport != BridgeTransport.websocket) {
      throw ArgumentError(
          'WebSocketBridgeConnectionHandler requires websocket transport');
    }
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> sendChecked(BridgePayload payload) async {
    if (!_connected) {
      throw StateError('WebSocket bridge is not connected');
    }
    // TODO: Wire this to web_socket_channel.
  }
}

class RedisBridgeConnectionHandler extends GuardedBridgeConnectionHandler {
  final _controller = StreamControllerAdapter();
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<BridgePayload> get messages => _controller.stream;

  @override
  Future<void> open(ConnectionConfig config) async {
    if (config.transport != BridgeTransport.redis) {
      throw ArgumentError(
          'RedisBridgeConnectionHandler requires redis transport');
    }
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> sendChecked(BridgePayload payload) async {
    if (!_connected) {
      throw StateError('Redis bridge is not connected');
    }
    // TODO: Wire this to a Redis pub/sub client suitable for mobile.
  }
}

class StreamControllerAdapter {
  final _controller = StreamController<BridgePayload>.broadcast();

  Stream<BridgePayload> get stream => _controller.stream;

  void add(BridgePayload payload) => _controller.add(payload);

  Future<void> close() => _controller.close();
}
