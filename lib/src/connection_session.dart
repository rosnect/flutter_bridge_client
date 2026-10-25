import 'dart:async';
import 'package:flutter/foundation.dart';
import 'bridge_client.dart';
import 'bridge_connection.dart';
import 'connection_config.dart';

/// Owns the app's single active transport, including replacement and failures.
class ConnectionSession extends ChangeNotifier {
  ConnectionSession(
      {BridgeConnectionHandler Function(BridgeTransport)? factory})
      : _factory = factory ?? createBridgeConnectionHandler;

  final BridgeConnectionHandler Function(BridgeTransport) _factory;
  BridgeClient? client;
  ConnectionConfig? config;
  StreamSubscription<BridgeConnectionStatus>? _status;
  bool busy = false;
  bool _disposed = false;
  String? error;

  bool get isConnected => client?.isConnected ?? false;

  Future<void> connect(ConnectionConfig next) async {
    if (busy) return;
    next.validate();
    busy = true;
    error = null;
    _notify();
    try {
      await _clear();
      config = next;
      final candidate = BridgeClient(_factory(next.transport));
      client = candidate;
      _status = candidate.connectionChanges.listen((_) => _notify());
      await candidate.connect(next);
    } on Object catch (e) {
      await _clear();
      error = e.toString();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> disconnect() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      await _clear();
      error = null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _clear() async {
    await _status?.cancel();
    _status = null;
    final previous = client;
    client = null;
    config = null;
    await previous?.disconnect();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_clear());
    super.dispose();
  }
}
