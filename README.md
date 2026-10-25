# Rosnect / Flutter ROS2 Embedded Bridge Client

Rosnect connects a phone to an MQTT broker and publishes/subscribes to bridge identifiers. The Android/iOS app lives in `rosnect/`.

## Connections

- Default broker: `192.168.0.81` (the development laptop).
- Normal MQTT: port `1883`.
- SSL/TLS MQTT: port `8883`.
- Optional username/password work with either mode.
- TLS uses system trust and verifies the broker certificate. An optional PEM CA certificate supports private authorities; mutual TLS additionally accepts a PEM client certificate, private key and optional key password. The broker hostname/IP must match its certificate.
- The green status dot means the broker accepted the connection. Loss of connection clears it. Reconnect manually with Connect/Reconnect.
- Only one connection is owned by `ConnectionSession`. Replacing it disconnects the previous transport first. Failed replacements leave the app disconnected.
- Settings remain while switching tabs; credentials and certificates are kept in memory only.
- WebSocket and Redis are unavailable until implemented.

The phone and laptop must be on a reachable network; the broker must accept LAN clients. USB is used to install the app, while the configured connection uses the phone's network.

## MQTT wire format

For connection `phone_1`, domain `7`:

- Phone publishes: `ros2embedded/7/phone_1/to_ros`
- Phone listens: `ros2embedded/7/phone_1/to_device`

Messages are UTF-8 JSON envelopes, for example:

```json
{"identifier":"robot.status","domain_id":7,"value_type":"string","value":"ready","timestamp_unix_ms":1792886400000}
```

Incoming malformed envelopes or wrong domains are ignored. The MQTT broker connection does not verify a remote ROS bridge domain. **The current ros2embedded ROS handlers remain placeholders and do not yet implement this JSON MQTT contract or protobuf conversion.**

The Sensors tab publishes sample values; actual phone sensor streaming is future work.

## Run and verify

```sh
flutter test
cd rosnect
flutter pub get
flutter test
flutter run -d <phone-device-id>
```

Build an installable Android debug APK with `flutter build apk --debug` from `rosnect/`. Output: `rosnect/build/app/outputs/flutter-apk/app-debug.apk`.

Run the actual broker smoke test from the package root:

```sh
dart run tool/mqtt_smoke.dart 192.168.0.81
```

Launcher icons are generated from `rosnect/assets/dark_rosnect.png` using `dart run flutter_launcher_icons` in `rosnect/`.
