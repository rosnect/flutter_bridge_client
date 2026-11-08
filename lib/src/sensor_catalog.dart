// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

/// Sensor categories used by the example phone application; no hardware is captured here.
enum PhoneSensorKind {
  accelerometer,
  gyroscope,
  magnetometer,
  location,
  light,
  barometer,
  camera,
  microphone,
  battery,
  touch,
}

/// Static labels and identifiers for a phone sensor.
class PhoneSensorDefinition {
  /// Creates a catalog entry.
  const PhoneSensorDefinition({
    required this.kind,
    required this.name,
    required this.defaultIdentifier,
    required this.description,
    this.requiresPermission = false,
  });

  /// Sensor category.
  final PhoneSensorKind kind;

  /// User-facing sensor name.
  final String name;

  /// Suggested bridge identifier.
  final String defaultIdentifier;

  /// User-facing capability description.
  final String description;

  /// Whether platform capture normally requires runtime permission.
  final bool requiresPermission;
}

/// Immutable application selection for a catalog sensor.
class EnabledPhoneSensor {
  /// Creates an enabled/disabled sensor selection.
  const EnabledPhoneSensor({
    required this.definition,
    required this.identifier,
    this.enabled = false,
  });

  /// Underlying sensor definition.
  final PhoneSensorDefinition definition;

  /// Selected logical bridge identifier.
  final String identifier;

  /// Whether the application intends to share this sensor.
  final bool enabled;

  /// Copies the selection with changed identifier and/or enabled state.
  EnabledPhoneSensor copyWith({
    String? identifier,
    bool? enabled,
  }) {
    return EnabledPhoneSensor(
      definition: definition,
      identifier: identifier ?? this.identifier,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Default phone sensor descriptions; availability must be checked on the device.
const phoneSensorCatalog = <PhoneSensorDefinition>[
  PhoneSensorDefinition(
    kind: PhoneSensorKind.accelerometer,
    name: 'Accelerometer',
    defaultIdentifier: 'phone.accelerometer',
    description: 'Device acceleration on x, y, z axes.',
  ),
  PhoneSensorDefinition(
    kind: PhoneSensorKind.gyroscope,
    name: 'Gyroscope',
    defaultIdentifier: 'phone.gyroscope',
    description: 'Angular velocity on x, y, z axes.',
  ),
  PhoneSensorDefinition(
    kind: PhoneSensorKind.magnetometer,
    name: 'Magnetometer',
    defaultIdentifier: 'phone.magnetometer',
    description: 'Magnetic field readings.',
  ),
  PhoneSensorDefinition(
    kind: PhoneSensorKind.location,
    name: 'Location',
    defaultIdentifier: 'phone.location',
    description: 'GPS latitude, longitude, altitude, and speed.',
    requiresPermission: true,
  ),
  PhoneSensorDefinition(
    kind: PhoneSensorKind.light,
    name: 'Light',
    defaultIdentifier: 'phone.light',
    description: 'Ambient light level when available.',
  ),
  PhoneSensorDefinition(
    kind: PhoneSensorKind.barometer,
    name: 'Barometer',
    defaultIdentifier: 'phone.pressure',
    description: 'Air pressure when available.',
  ),
  PhoneSensorDefinition(
    kind: PhoneSensorKind.camera,
    name: 'Camera',
    defaultIdentifier: 'phone.camera.frame',
    description: 'Camera frame metadata or compressed frame payload.',
    requiresPermission: true,
  ),
  PhoneSensorDefinition(
    kind: PhoneSensorKind.microphone,
    name: 'Microphone',
    defaultIdentifier: 'phone.microphone.level',
    description: 'Audio level or feature data.',
    requiresPermission: true,
  ),
  PhoneSensorDefinition(
    kind: PhoneSensorKind.battery,
    name: 'Battery',
    defaultIdentifier: 'phone.battery',
    description: 'Battery level and charging state.',
  ),
  PhoneSensorDefinition(
    kind: PhoneSensorKind.touch,
    name: 'Touch',
    defaultIdentifier: 'phone.touch',
    description: 'Touch, button, or joystick-style control data.',
  ),
];

/// Creates fresh selections with all sensors initially disabled.
List<EnabledPhoneSensor> defaultSensorSelection() {
  return [
    for (final definition in phoneSensorCatalog)
      EnabledPhoneSensor(
        definition: definition,
        identifier: definition.defaultIdentifier,
      ),
  ];
}
