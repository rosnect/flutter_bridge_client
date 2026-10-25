enum BridgeTransport { mqtt, websocket, redis }

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
    this.useTls = false,
    this.caCertificate,
    this.clientCertificate,
    this.clientPrivateKey,
    this.privateKeyPassword,
  });

  final String connectionId;
  final int domainId;
  final BridgeTransport transport;
  final String host;
  final int? port;
  final String? username;
  final String? password;
  final String baseTopic;
  final bool useTls;
  final String? caCertificate;
  final String? clientCertificate;
  final String? clientPrivateKey;
  final String? privateKeyPassword;

  int get effectivePort => port ?? (useTls ? 8883 : 1883);
  String get publishTopic => '$baseTopic/$domainId/$connectionId/to_ros';
  String get subscribeTopic => '$baseTopic/$domainId/$connectionId/to_device';

  void validate() {
    if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(connectionId)) {
      throw ArgumentError('Connection ID must use letters, numbers, _, - or .');
    }
    if (domainId < 0 || domainId > 0xffffffff) {
      throw ArgumentError('Domain ID must be between 0 and 4294967295.');
    }
    if (host.trim().isEmpty || host.contains('://') || host.contains('/')) {
      throw ArgumentError(
          'Enter a broker hostname or IP without a URL scheme.');
    }
    if (effectivePort < 1 || effectivePort > 65535) {
      throw ArgumentError('Port must be between 1 and 65535.');
    }
    if (baseTopic.isEmpty || baseTopic.contains(RegExp(r'[+#]'))) {
      throw ArgumentError('Base topic must not be empty or contain wildcards.');
    }
    final hasCert = clientCertificate?.trim().isNotEmpty ?? false;
    final hasKey = clientPrivateKey?.trim().isNotEmpty ?? false;
    if (hasCert != hasKey) {
      throw ArgumentError(
          'Provide both the client certificate and private key.');
    }
  }
}
