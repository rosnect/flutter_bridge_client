# Rosnect bridge client

`ros2_embedded_bridge_client` connects Flutter applications to
[ros2embedded](https://github.com/rosnect/ros2embedded) and ROS 2 over MQTT.
It provides typed JSON messaging, verified TLS, one active connection per
session, and acknowledged device-advertised ROS interfaces.

The reusable library is published separately from the
[Rosnect phone application](https://github.com/rosnect/flutter_bridge_client/tree/main/rosnect).
The phone app captures Android sensors and camera frames; this library supplies
the connection/protocol layer and does not request camera or microphone access.

## Features

- MQTT 3.1.1 on native Flutter platforms using `dart:io`.
- Username/password, verified TLS, private CA certificates and mutual TLS.
- Typed payloads routed by identifier and unsigned 32-bit logical domain.
- Full interface snapshots with matching acknowledgements, retries, host config
  requests and normalized ROS topic discovery.
- `ChangeNotifier` connection/interface state for Flutter UIs.
- Transport interfaces for custom implementations, plus subscription/sensor models.

Only MQTT is implemented. WebSocket and Redis enum values are reserved and throw
`UnsupportedError`. Browser/WebSocket support is not provided. The library's
MQTT transport can run on native Android, iOS and desktop Flutter applications;
actual sensor capture in the separate Rosnect app is Android-only.

## Installation

The initial `0.1.0` pub.dev release is being prepared. Once it is published:

```yaml
dependencies:
  ros2_embedded_bridge_client: ^0.1.0
```

Before publication, use the public Git repository:

```yaml
dependencies:
  ros2_embedded_bridge_client:
    git:
      url: https://github.com/rosnect/flutter_bridge_client.git
      ref: main
```

Requires Dart 3.2+ and Flutter 3.16+. Import the public library:

```dart
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';
```

## Connect and advertise interfaces

Create one session and one interface owner in your application's state. Give each
simultaneously connected device its own connection ID.

```dart
final session = ConnectionSession();
final interfaces = DeviceInterfaces(session);

interfaces.update([
  {
    'identifier': 'device.telemetry',
    'direction': 'DEVICE_TO_ROS',
    'value_type': 'JSON',
    'ros_topic': 'telemetry',
  },
  {
    'identifier': 'robot.command',
    'direction': 'ROS_TO_DEVICE',
    'value_type': 'STRING',
    'ros_topic': 'robot_command',
  },
]);

await session.connect(const ConnectionConfig(
  connectionId: 'flutter_demo',
  domainId: 7,
  transport: BridgeTransport.mqtt,
  host: 'BROKER_HOSTNAME_OR_IP',
));

// Connection failures populate session.error. Validation errors throw.
if (!session.isConnected) {
  throw StateError(session.error ?? 'MQTT connection failed');
}
```

Two different states matter:

- `session.isConnected`: the broker connection is available.
- `interfaces.ready`: the host accepted the current full interface snapshot.

Listen to these `ChangeNotifier`s or use an `AnimatedBuilder` to update your UI.
Enable publishing only when both are true. Configuration readiness records an
acknowledgement; it is not a continuous host-liveness check.

The [runnable example](https://github.com/rosnect/flutter_bridge_client/tree/main/example)
shows the complete connect, acknowledgement, publish, subscribe and disposal flow.

## Send and receive

From a UI action after interface readiness:

```dart
if (session.isConnected && interfaces.ready) {
  await session.client!.writeData(
    'device.telemetry',
    {'temperature_celsius': 23.4},
    valueType: BridgeValueType.json,
  );
}

final commands = session.client!.subscribe('robot.command').listen((payload) {
  print('Received command: ${payload.value}');
});
```

The JSON binding above becomes `std_msgs/msg/String` containing JSON on ROS.
For supported native sensor types, add `ros_message_type`, for example
`sensor_msgs/msg/Imu`, to a JSON binding and supply the exact measurement schema
expected by the host. This library does not invent units, covariance, calibration
or timestamps for your sensor measurements. See the
[native sensor contract](https://github.com/rosnect/ros2embedded/blob/main/docs/native_sensors.md).

Cancel stream listeners and dispose state when leaving the application:

```dart
await commands.cancel();
interfaces.dispose();
session.dispose();
```

## Start the ROS host

Use a built and sourced ros2embedded installation with device configuration:

```bash
ros2 run bridge_manager bridge_manager --ros-args \
  -p auto_start:=true -p protocol:=mqtt \
  -p connection_id:=flutter_demo -p domain_id:=7 \
  -p mqtt_broker:=BROKER_HOSTNAME_OR_IP -p mqtt_port:=1883 \
  -p config_source:=device
```

For this example:

```bash
ros2 topic echo /ros2embedded/domain_7/connection_flutter_5fdemo/telemetry
ros2 topic pub --once \
  /ros2embedded/domain_7/connection_flutter_5fdemo/robot_command \
  std_msgs/msg/String "{data: 'hello Flutter'}"
```

The `_5f` escapes `_` in the connection ID. Use `interfaces.rosNamespace` and
`interfaces.topicFor(identifier)` rather than constructing output names yourself.
The logical `domainId` controls bridge routing; it is independent of DDS's
`ROS_DOMAIN_ID` environment variable. See the
[host discovery contract](https://github.com/rosnect/ros2embedded/blob/main/docs/device_configuration.md).

## TLS and authentication

```dart
final config = ConnectionConfig(
  connectionId: 'flutter_demo',
  domainId: 7,
  transport: BridgeTransport.mqtt,
  host: 'mqtt.example.com',
  useTls: true, // Defaults to port 8883; normal MQTT defaults to 1883.
  username: username,
  password: password,
  caCertificate: privateCaPem, // Optional: system roots are trusted by default.
  clientCertificate: clientCertificatePem, // Optional mutual TLS pair.
  clientPrivateKey: clientPrivateKeyPem,
);
```

Omit optional fields when not used. Client certificate and private key must be
provided together. The hostname/IP must match the broker certificate. Credentials
and certificates are kept in memory by this library; application storage is up
to the caller. The complete Rosnect app has editable TLS controls.

For Android, include Internet access in the application's manifest:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

For local-network access on iOS, provide `NSLocalNetworkUsageDescription` in the
app's `Info.plist`. Hardware permissions belong to the app doing capture.

## Protocol and connection behavior

For connection `flutter_demo`, domain `7`, the default MQTT prefix is
`ros2embedded/7/flutter_demo/`:

| Topic suffix | Purpose |
|---|---|
| `to_ros` | Device publishes typed JSON envelopes, QoS 0, not retained |
| `to_device` | Device receives host data |
| `config` | Device publishes full retained interface snapshots, QoS 1 |
| `config_status` | Host accepts/rejects a correlated snapshot |
| `config_request` | Host requests the current snapshot |

```json
{"identifier":"device.telemetry","domain_id":7,"value_type":"json","value":{"temperature_celsius":23.4},"timestamp_unix_ms":1794050000000}
```

Configuration types use uppercase enum names such as `JSON`; data-envelope types
use lowercase names such as `json`. Configuration and payload encoding are JSON
in this client; protobuf encoding is not implemented here. Malformed incoming
messages and messages in another logical domain are ignored.

`ConnectionSession` disconnects the previous transport before replacing it.
A failed replacement leaves the session disconnected. MQTT reconnect is manual.
A completed `writeData` means the client accepted the publish, not that a ROS
subscriber acknowledged it. Applications issuing robot actions should add their
own correlation, expiry and results rather than treating transport delivery as
execution success.

## Rosnect app and development

The separate [Rosnect app](https://github.com/rosnect/flutter_bridge_client/tree/main/rosnect)
has editable MQTT settings, native Android sensors, camera preview, two-column
tiles, tap-to-open graphs, X/Y/Z selection, light/dark themes and a circular splash
logo. See its README for capture support and app build instructions.

```bash
flutter pub get
flutter analyze
flutter test
cd rosnect
flutter pub get
flutter analyze
flutter test
```

For publication and contributions, see
[CONTRIBUTING.md](https://github.com/rosnect/flutter_bridge_client/blob/main/CONTRIBUTING.md)
and the [release guide](https://github.com/rosnect/flutter_bridge_client/blob/main/docs/publishing.md).

## License and contact

Copyright 2026 Rosnect contributors. Licensed under the
[Apache License, Version 2.0](https://github.com/rosnect/flutter_bridge_client/blob/main/LICENSE).
See `LICENSE` and `NOTICE`. Third-party dependencies retain their own licenses.

Maintained by Rosnect. Contact: [rosnect.dev@tutamail.com](mailto:rosnect.dev@tutamail.com).
