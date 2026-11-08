// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

/// Transport choices; WebSocket and Redis are reserved and not implemented.
enum BridgeTransport { mqtt, websocket, redis }

/// Immutable broker settings and logical bridge identity.
class ConnectionConfig {
  /// Creates configuration; call [validate] before use.
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

  /// Unique device connection ID, also used as the MQTT client ID.
  final String connectionId;

  /// Unsigned 32-bit logical routing domain, independent of ROS_DOMAIN_ID.
  final int domainId;

  /// Selected transport. Only MQTT is currently available.
  final BridgeTransport transport;

  /// Reachable broker hostname/IP, without a URL scheme or path.
  final String host;

  /// Explicit broker port; null uses the standard port for the TLS setting.
  final int? port;

  /// Optional broker authentication username.
  final String? username;

  /// Optional broker authentication password; persistence is the caller's responsibility.
  final String? password;

  /// MQTT topic prefix, normally ros2embedded.
  final String baseTopic;

  /// Enables TLS with system trust and certificate/hostname verification.
  final bool useTls;

  /// Optional PEM CA certificate added to the trusted roots.
  final String? caCertificate;

  /// Optional PEM client certificate chain for mutual TLS.
  final String? clientCertificate;

  /// PEM private key paired with [clientCertificate].
  final String? clientPrivateKey;

  /// Optional password for the client private key.
  final String? privateKeyPassword;

  /// Explicit port, or 1883 for MQTT and 8883 for TLS.
  int get effectivePort => port ?? (useTls ? 8883 : 1883);

  /// Device-to-ROS MQTT data topic.
  String get publishTopic => '$baseTopic/$domainId/$connectionId/to_ros';

  /// ROS-to-device MQTT data topic.
  String get subscribeTopic => '$baseTopic/$domainId/$connectionId/to_device';

  /// Validates identity, domain, host, port and certificate/key pairing.
  ///
  /// Throws [ArgumentError] for invalid configuration.
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
