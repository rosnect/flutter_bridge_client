import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';

const sensorMessageTypes = <PhoneSensorKind, String>{
  PhoneSensorKind.accelerometer: 'sensor_msgs/msg/Imu',
  PhoneSensorKind.gyroscope: 'sensor_msgs/msg/Imu',
  PhoneSensorKind.magnetometer: 'sensor_msgs/msg/MagneticField',
  PhoneSensorKind.location: 'sensor_msgs/msg/NavSatFix',
  PhoneSensorKind.light: 'sensor_msgs/msg/Illuminance',
  PhoneSensorKind.barometer: 'sensor_msgs/msg/FluidPressure',
  PhoneSensorKind.camera: 'sensor_msgs/msg/CompressedImage',
  PhoneSensorKind.battery: 'sensor_msgs/msg/BatteryState',
  PhoneSensorKind.microphone: 'std_msgs/msg/String',
  PhoneSensorKind.touch: 'std_msgs/msg/String',
};
String sensorTopic(PhoneSensorKind kind) =>
    kind == PhoneSensorKind.camera ? 'camera/image/compressed' : kind.name;

Map<String, Object?> sensorRosValue(
    PhoneSensorKind kind, Object raw, int timestamp) {
  final header = <String, Object?>{
    'stamp': {'sec': timestamp ~/ 1000, 'nanosec': timestamp % 1000 * 1000000},
    'frame_id':
        kind == PhoneSensorKind.camera ? 'phone_camera_optical' : 'phone_link',
  };
  Map<String, Object?> vector(List values, [double scale = 1]) => {
        'x': (values[0] as num) * scale,
        'y': (values[1] as num) * scale,
        'z': (values[2] as num) * scale
      };
  switch (kind) {
    case PhoneSensorKind.accelerometer:
    case PhoneSensorKind.gyroscope:
      final acceleration = kind == PhoneSensorKind.accelerometer;
      return {
        'header': header,
        'orientation': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
        'orientation_covariance': [-1, 0, 0, 0, 0, 0, 0, 0, 0],
        if (acceleration) 'linear_acceleration': vector(raw as List),
        if (!acceleration) 'angular_velocity': vector(raw as List),
        if (acceleration)
          'angular_velocity_covariance': [-1, 0, 0, 0, 0, 0, 0, 0, 0],
        if (!acceleration)
          'linear_acceleration_covariance': [-1, 0, 0, 0, 0, 0, 0, 0, 0]
      };
    case PhoneSensorKind.magnetometer:
      return {'header': header, 'magnetic_field': vector(raw as List, 1e-6)};
    case PhoneSensorKind.light:
      return {
        'header': header,
        'illuminance': (raw as List).first,
        'variance': 0
      };
    case PhoneSensorKind.barometer:
      return {
        'header': header,
        'fluid_pressure': ((raw as List).first as num) * 100,
        'variance': 0
      };
    case PhoneSensorKind.location:
      final location = Map<String, Object?>.from(raw as Map);
      final accuracy = (location['accuracy'] as num?)?.toDouble();
      final covariance = List<double>.filled(9, 0);
      if (accuracy != null) {
        covariance[0] = accuracy * accuracy;
        covariance[4] = accuracy * accuracy;
      }
      return {
        'header': header,
        'status': {
          'status': 0,
          'service': location['provider'] == 'gps' ? 1 : 0
        },
        'latitude': location['latitude'], 'longitude': location['longitude'],
        // Android altitude is WGS84 ellipsoid height; an absent value stays absent.
        if (location.containsKey('altitude')) 'altitude': location['altitude'],
        'position_covariance': covariance, 'position_covariance_type': 0
      };
    case PhoneSensorKind.camera:
      return {
        'header': header,
        'format': 'jpeg',
        'data_base64': base64Encode(raw as List<int>)
      };
    case PhoneSensorKind.battery:
      final battery = Map<String, Object?>.from(raw as Map);
      return {
        'header': header,
        'voltage': battery['voltage'],
        'temperature': battery['temperature'],
        if ((battery['percentage'] as num? ?? -1) >= 0)
          'percentage': battery['percentage'],
        'present': true,
        'power_supply_status': battery['power_supply_status'] ?? 0
      };
    case PhoneSensorKind.microphone:
    case PhoneSensorKind.touch:
      return {'header': header, ...Map<String, Object?>.from(raw as Map)};
  }
}

class LiveSensors extends ChangeNotifier with WidgetsBindingObserver {
  LiveSensors(this.session) : interfaces = DeviceInterfaces(session) {
    interfaces.addListener(_changed);
    session.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      _events = const EventChannel('rosnect/sensor_events')
          .receiveBroadcastStream()
          .listen(_event, onError: (Object e) {
        globalError = '$e';
        _notify();
      });
      _loadCapabilities();
    } else {
      globalError = 'Live capture currently supports Android phones.';
    }
  }
  final ConnectionSession session;
  final DeviceInterfaces interfaces;
  static const _native = MethodChannel('rosnect/sensors');
  final Map<PhoneSensorKind, EnabledPhoneSensor> sensors = {
    for (final item in defaultSensorSelection()) item.definition.kind: item,
  };
  final Map<PhoneSensorKind, bool> available = {};
  final Map<PhoneSensorKind, String> errors = {};
  final Map<PhoneSensorKind, Object> latest = {};
  final Map<PhoneSensorKind, int> sent = {};
  final Map<String, BridgeValueType> subscriptions = {};
  final Set<PhoneSensorKind> _running = {};
  StreamSubscription<dynamic>? _events;
  bool _disposed = false, _syncing = false, _again = false, _foreground = true;
  bool frontCamera = false;
  int cameraFps = 2;
  Uint8List? cameraPreview;
  String? globalError;
  DateTime? _lastUi;

  Future<void> _loadCapabilities() async {
    try {
      final caps =
          await _native.invokeMapMethod<String, bool>('capabilities') ?? {};
      for (final kind in PhoneSensorKind.values) {
        available[kind] = caps[kind.name] ?? false;
      }
    } on Object catch (e) {
      globalError = 'Live capture is currently supported on Android. $e';
    }
    _notify();
  }

  bool get streaming => session.isConnected && interfaces.ready && _foreground;

  Future<void> enable(PhoneSensorKind kind, bool value) async {
    errors.remove(kind);
    if (value && subscriptions.containsKey(sensors[kind]!.identifier)) {
      errors[kind] = 'A command subscription already uses this identifier';
      _notify();
      return;
    }
    sensors[kind] = sensors[kind]!.copyWith(enabled: value);
    if (!value) {
      await _stop(kind);
      if (kind == PhoneSensorKind.camera) cameraPreview = null;
    }
    _advertise();
  }

  void rename(PhoneSensorKind kind, String identifier) {
    if (!RegExp(r'^[A-Za-z0-9_.\-/]{1,96}$').hasMatch(identifier)) {
      errors[kind] = 'Use 1–96 letters, digits, _, -, . or /';
      _notify();
      return;
    }
    if (subscriptions.containsKey(identifier)) {
      errors[kind] = 'A subscription uses that identifier';
      _notify();
      return;
    }
    if (sensors.entries
        .any((e) => e.key != kind && e.value.identifier == identifier)) {
      errors[kind] = 'Another sensor uses that identifier';
      _notify();
      return;
    }
    sensors[kind] = sensors[kind]!.copyWith(identifier: identifier);
    errors.remove(kind);
    _advertise();
  }

  void addSubscription(String identifier, BridgeValueType type) {
    if (!RegExp(r'^[A-Za-z0-9_.\-/]{1,96}$').hasMatch(identifier)) {
      globalError = 'Invalid subscription identifier';
      _notify();
      return;
    }
    // Sensor interfaces have typed ROS schemas; command subscriptions stay independent.
    if (sensors.values.any((e) => e.enabled && e.identifier == identifier)) {
      globalError =
          'Choose a separate command identifier for sensor subscriptions.';
      _notify();
      return;
    }
    subscriptions[identifier] = type;
    globalError = null;
    _advertise();
  }

  void removeSubscription(String identifier) {
    subscriptions.remove(identifier);
    _advertise();
  }

  String configType(BridgeValueType type) =>
      type == BridgeValueType.boolValue ? 'BOOL' : type.name.toUpperCase();
  void _advertise() {
    interfaces.update([
      for (final item in sensors.values.where((s) => s.enabled))
        {
          'identifier': item.identifier,
          'direction': 'DEVICE_TO_ROS',
          'value_type': 'JSON',
          'ros_topic': sensorTopic(item.definition.kind),
          'ros_message_type': sensorMessageTypes[item.definition.kind],
        },
      for (final entry in subscriptions.entries)
        {
          'identifier': entry.key,
          'direction': 'ROS_TO_DEVICE',
          'value_type': configType(entry.value),
        },
    ]);
    _changed();
  }

  Future<void> cameraOptions({bool? front, int? fps}) async {
    if (front != null) frontCamera = front;
    if (fps != null) cameraFps = fps;
    await _stop(PhoneSensorKind.camera);
    _changed();
  }

  void _changed() {
    _notify();
    unawaited(_sync());
  }

  Future<void> _sync() async {
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        for (final kind in PhoneSensorKind.values) {
          if (_disposed) return;
          final wanted =
              streaming && sensors[kind]!.enabled && !errors.containsKey(kind);
          if (!wanted && _running.contains(kind)) await _stop(kind);
          if (wanted && !_running.contains(kind)) {
            try {
              if (kind != PhoneSensorKind.touch) {
                await _native.invokeMethod<void>('start', {
                  'kind': kind.name,
                  'front': frontCamera,
                  'fps': cameraFps
                });
              }
              if (!_disposed) _running.add(kind);
            } on Object catch (e) {
              errors[kind] = '$e';
            }
            _notify();
          }
        }
      } while (_again);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _stop(PhoneSensorKind kind) async {
    _running.remove(kind);
    if (kind == PhoneSensorKind.touch) return;
    try {
      await _native.invokeMethod<void>('stop', {'kind': kind.name});
    } on Object {/* Unsupported platform or activity already stopped. */}
  }

  void _event(dynamic event) {
    if (_disposed || event is! Map) return;
    final kind = PhoneSensorKind.values
        .where((k) => k.name == event['kind'])
        .firstOrNull;
    if (kind == null) return;
    if (event['error'] != null) {
      errors[kind] = '${event['error']}';
      _running.remove(kind);
      _notify();
      return;
    }
    if (!streaming || !sensors[kind]!.enabled || event['value'] == null) return;
    final value = event['value'] as Object;
    if (kind == PhoneSensorKind.camera) cameraPreview = value as Uint8List;
    _publish(
        kind,
        value,
        (event['timestamp_unix_ms'] as int?) ??
            DateTime.now().millisecondsSinceEpoch);
  }

  void touch(Offset position, Size size, String phase) {
    if (!streaming || !sensors[PhoneSensorKind.touch]!.enabled) return;
    _publish(
        PhoneSensorKind.touch,
        {
          'x': position.dx / size.width,
          'y': position.dy / size.height,
          'phase': phase
        },
        DateTime.now().millisecondsSinceEpoch);
  }

  void _publish(PhoneSensorKind kind, Object value, int timestamp) {
    latest[kind] = kind == PhoneSensorKind.camera
        ? '${(value as List).length} JPEG bytes'
        : value;
    try {
      final payload = sensorRosValue(kind, value, timestamp);
      session.client!
          .writeData(sensors[kind]!.identifier, payload,
              valueType: BridgeValueType.json)
          .then((_) {
        sent[kind] = (sent[kind] ?? 0) + 1;
      }).catchError((Object e) {
        errors[kind] = '$e';
        _notify();
      });
    } on Object catch (e) {
      errors[kind] = '$e';
    }
    if (_lastUi == null ||
        DateTime.now().difference(_lastUi!).inMilliseconds >= 250) {
      _lastUi = DateTime.now();
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _changed();
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _running.clear();
      _changed();
    }
  }

  Future<void> settings() => _native.invokeMethod<void>('settings');
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_changed);
    interfaces.removeListener(_changed);
    interfaces.dispose();
    _events?.cancel();
    if (Platform.isAndroid) {
      _native.invokeMethod<void>('stopAll').catchError((Object _) {});
    }
    super.dispose();
  }
}
