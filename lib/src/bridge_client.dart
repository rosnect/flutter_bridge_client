// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'bridge_connection.dart';
import 'bridge_payload.dart';
import 'connection_config.dart';

/// Identifier-based, domain-scoped messaging over a bridge transport.
class BridgeClient {
  /// Creates a client using the supplied transport handler.
  BridgeClient(this._handler);

  final BridgeConnectionHandler _handler;
  ConnectionConfig? _config;

  /// Whether the transport currently has a broker connection.
  bool get isConnected => _handler.isConnected;

  /// Broadcast transport state changes; this does not imply ROS readiness.
  Stream<BridgeConnectionStatus> get connectionChanges =>
      _handler.connectionChanges;

  /// Device-configuration requests and acknowledgements from the host bridge.
  Stream<Map<String, Object?>> get configurationMessages =>
      _handler is BridgeConfigurationChannel
          ? (_handler as BridgeConfigurationChannel).configurationMessages
          : const Stream.empty();

  /// Sends a complete interface snapshot through a configuration-capable transport.
  Future<void> sendConfiguration(Map<String, Object?> snapshot) =>
      _handler is BridgeConfigurationChannel
          ? (_handler as BridgeConfigurationChannel).sendConfiguration(snapshot)
          : Future.error(
              UnsupportedError('Transport has no configuration channel'));

  /// The configured logical bridge domain, or null before connection.
  int? get domainId => _config?.domainId;

  /// Incoming payloads filtered to the configured logical domain.
  Stream<BridgePayload> get messages => _handler.messages.where(_matchesDomain);

  /// Validates configuration and opens the transport connection.
  Future<void> connect(ConnectionConfig config) async {
    config.validate();
    _config = null;
    await _handler.connect(config);
    _config = config;
  }

  /// Disconnects the transport and clears the client configuration.
  Future<void> disconnect() async {
    await _handler.disconnect();
    _config = null;
  }

  /// Sends a value with the configured domain and the current Unix timestamp.
  ///
  /// An explicit [valueType] overrides inference. Throws when disconnected; a
  /// completed send does not acknowledge processing by a ROS subscriber.
  Future<void> writeData(
    String identifier,
    Object value, {
    BridgeValueType? valueType,
  }) {
    final config = _requireConfig();
    return _handler.send(
      BridgePayload(
        identifier: identifier,
        domainId: config.domainId,
        valueType: valueType ?? inferValueType(value),
        value: value,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Filters incoming values by exact identifier; cancel your subscription on disposal.
  Stream<BridgePayload> subscribe(String identifier) {
    return messages.where((payload) => payload.identifier == identifier);
  }

  ConnectionConfig _requireConfig() {
    final config = _config;
    if (config == null || !_handler.isConnected) {
      throw StateError('BridgeClient is not connected');
    }
    return config;
  }

  bool _matchesDomain(BridgePayload payload) {
    final config = _config;
    return config != null && payload.domainId == config.domainId;
  }
}

/// Infers a wire type from a Dart value; structured objects default to JSON.
BridgeValueType inferValueType(Object value) {
  if (value is bool) {
    return BridgeValueType.boolValue;
  }
  if (value is int) {
    return BridgeValueType.int64;
  }
  if (value is double) {
    return BridgeValueType.float64;
  }
  if (value is String) {
    return BridgeValueType.string;
  }
  if (value is List<int>) {
    return BridgeValueType.bytes;
  }
  return BridgeValueType.json;
}
