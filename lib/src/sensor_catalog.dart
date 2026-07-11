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

class PhoneSensorDefinition {
  const PhoneSensorDefinition({
    required this.kind,
    required this.name,
    required this.defaultIdentifier,
    required this.description,
    this.requiresPermission = false,
  });

  final PhoneSensorKind kind;
  final String name;
  final String defaultIdentifier;
  final String description;
  final bool requiresPermission;
}

class EnabledPhoneSensor {
  const EnabledPhoneSensor({
    required this.definition,
    required this.identifier,
    this.enabled = false,
  });

  final PhoneSensorDefinition definition;
  final String identifier;
  final bool enabled;

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

List<EnabledPhoneSensor> defaultSensorSelection() {
  return [
    for (final definition in phoneSensorCatalog)
      EnabledPhoneSensor(
        definition: definition,
        identifier: definition.defaultIdentifier,
      ),
  ];
}
