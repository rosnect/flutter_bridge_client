// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'bridge_client.dart';
import 'bridge_connection.dart';
import 'connection_config.dart';

/// Owns the app's single active transport, including replacement and failures.
class ConnectionSession extends ChangeNotifier {
  /// Creates session ownership; [factory] can inject a custom/test transport.
  ConnectionSession(
      {BridgeConnectionHandler Function(BridgeTransport)? factory})
      : _factory = factory ?? createBridgeConnectionHandler;

  final BridgeConnectionHandler Function(BridgeTransport) _factory;

  /// The active client, or null when disconnected or replacement fails.
  BridgeClient? client;

  /// Configuration of the active connection.
  ConnectionConfig? config;
  StreamSubscription<BridgeConnectionStatus>? _status;

  /// Whether a connect/disconnect operation is in progress.
  bool busy = false;
  bool _disposed = false;

  /// Latest connection failure, suitable for presenting in the UI.
  String? error;

  /// Whether the owned client is connected to its broker.
  bool get isConnected => client?.isConnected ?? false;

  /// Replaces the previous connection before opening the next.
  ///
  /// Validation errors throw. Connection failures clear the client and populate
  /// [error]. Calls while [busy] are ignored.
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

  /// Disconnects the owned transport; calls while [busy] are ignored.
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
