enum BridgeTransport {
  mqtt,
  websocket,
  redis,
}

class ConnectionConfig {
  const ConnectionConfig({
    required this.connectionId,
    required this.domainId,
    required this.transport,
    required this.host,
    this.port,
    this.username,
    this.password,
    this.baseTopic = 'ros2embedded',
  });

  final String connectionId;
  final int domainId;
  final BridgeTransport transport;
  final String host;
  final int? port;
  final String? username;
  final String? password;
  final String baseTopic;

  void validate() {
    if (connectionId.trim().isEmpty) {
      throw ArgumentError.value(
          connectionId, 'connectionId', 'must not be empty');
    }
    if (domainId < 0) {
      throw ArgumentError.value(domainId, 'domainId', 'must be >= 0');
    }
    if (host.trim().isEmpty) {
      throw ArgumentError.value(host, 'host', 'must not be empty');
    }
  }
}
