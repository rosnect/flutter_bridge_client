import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'connection_session.dart';

/// Full, acknowledged device interface snapshots, independent of device hardware.
class DeviceInterfaces extends ChangeNotifier {
  DeviceInterfaces(this.session) {
    session.addListener(_connectionChanged);
  }
  final ConnectionSession session;
  Object? _client;
  StreamSubscription<Map<String, Object?>>? _control;
  Timer? _retry;
  List<Map<String, Object?>> _desired = [];
  Map<String, Object?>? _pending, _accepted;
  List<Map<String, Object?>> normalized = [];
  String? error;
  String rosNamespace = '';
  bool ready = false;
  int _attempts = 0, _revision = 0;
  bool _disposed = false;

  void update(List<Map<String, Object?>> bindings) {
    if (jsonEncode(bindings) == jsonEncode(_desired)) return;
    _desired = bindings.map((b) => Map<String, Object?>.from(b)).toList();
    ready = false;
    error = null;
    if (_pending == null) _begin();
    _notify();
  }

  void resync() {
    _pending = null;
    _retry?.cancel();
    _begin();
  }

  void _connectionChanged() {
    final client = session.client;
    if (!session.isConnected) {
      _retry?.cancel();
      _pending = null;
      ready = false;
      _control?.cancel();
      _control = null;
      _client = null;
      _notify();
      return;
    }
    if (identical(client, _client)) return;
    _client = client;
    _control = client!.configurationMessages.listen(_receive);
    _accepted = null;
    _begin();
  }

  void _begin() {
    final config = session.config;
    if (!session.isConnected || config == null) return;
    ready = false;
    error = null;
    _attempts = 0;
    _pending = {
      'schema_version': 1,
      'configuration_id':
          '${DateTime.now().microsecondsSinceEpoch}-${_revision++}',
      'connection_id': config.connectionId,
      'domain_id': config.domainId,
      'protocol': 'PROTOCOL_MQTT',
      'bindings': _desired,
    };
    _send();
    _armRetry();
    _notify();
  }

  void _armRetry() {
    _attempts = 0;
    _retry?.cancel();
    _retry = Timer.periodic(const Duration(seconds: 2), (_) {
      if (++_attempts >= 5) {
        _retry?.cancel();
        error =
            'Waiting for ROS bridge acknowledgement. Check config_source=device, connection ID and domain.';
        _notify();
      } else {
        _send();
      }
    });
    _notify();
  }

  void _send() {
    final snapshot = _pending ?? _accepted;
    if (snapshot != null && session.isConnected) {
      session.client!.sendConfiguration(snapshot).catchError((Object e) {
        error = '$e';
        ready = false;
        _notify();
      });
    }
  }

  void _receive(Map<String, Object?> message) {
    final config = session.config;
    if (config == null ||
        message['connection_id'] != config.connectionId ||
        message['domain_id'] != config.domainId ||
        message['schema_version'] != 1) return;
    if (message['_control'] == 'config_request') {
      if (message['config_encoding'] != 'json' ||
          message['payload_encoding'] != 'json') {
        ready = false;
        error =
            'Rosnect requires config_encoding=json and payload_encoding=json.';
        _retry?.cancel();
        _notify();
        return;
      }
      if (_pending == null && _accepted == null) {
        _begin();
      } else {
        _pending ??= _accepted;
        ready = false;
        _send();
        _armRetry();
        _notify();
      }
      return;
    }
    if (_pending == null ||
        message['configuration_id'] != _pending!['configuration_id']) return;
    _retry?.cancel();
    if (message['accepted'] != true) {
      error = 'ROS bridge rejected interfaces: ${message['error']}';
      ready = false;
      _pending = null;
      // Restore the last valid retained snapshot; never leave a rejected snapshot retained.
      if (_accepted != null) _send();
      _notify();
      return;
    }
    _accepted = _pending;
    _pending = null;
    normalized = (message['bindings'] as List? ?? [])
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList();
    rosNamespace = message['ros_namespace'] as String? ?? '';
    if (jsonEncode(_accepted!['bindings']) != jsonEncode(_desired)) {
      _begin();
      return;
    }
    ready = true;
    error = null;
    _notify();
  }

  String? topicFor(String identifier) {
    for (final binding in normalized) {
      if (binding['identifier'] == identifier) {
        final topic = binding['ros_topic'] as String?;
        return topic == null
            ? null
            : topic.startsWith('/')
                ? topic
                : '$rosNamespace/$topic';
      }
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_connectionChanged);
    _retry?.cancel();
    _control?.cancel();
    super.dispose();
  }
}
