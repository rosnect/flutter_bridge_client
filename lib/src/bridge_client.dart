import 'bridge_connection.dart';
import 'bridge_payload.dart';
import 'connection_config.dart';

class BridgeClient {
  BridgeClient(this._handler);

  final BridgeConnectionHandler _handler;
  ConnectionConfig? _config;

  bool get isConnected => _handler.isConnected;
  Stream<BridgeConnectionStatus> get connectionChanges =>
      _handler.connectionChanges;
  Stream<Map<String, Object?>> get configurationMessages =>
      _handler is BridgeConfigurationChannel
          ? (_handler as BridgeConfigurationChannel).configurationMessages
          : const Stream.empty();
  Future<void> sendConfiguration(Map<String, Object?> snapshot) =>
      _handler is BridgeConfigurationChannel
          ? (_handler as BridgeConfigurationChannel).sendConfiguration(snapshot)
          : Future.error(
              UnsupportedError('Transport has no configuration channel'));
  int? get domainId => _config?.domainId;
  Stream<BridgePayload> get messages => _handler.messages.where(_matchesDomain);

  Future<void> connect(ConnectionConfig config) async {
    config.validate();
    _config = null;
    await _handler.connect(config);
    _config = config;
  }

  Future<void> disconnect() async {
    await _handler.disconnect();
    _config = null;
  }

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
