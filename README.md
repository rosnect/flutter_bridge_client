# Flutter ROS2 Embedded Bridge Client

Movable Flutter client library and example app for connecting Android/iOS devices into the `ros2embedded` bridge.

The mobile app acts like another bridge device:

- Connect with a selected transport.
- Use a shared `domainId` guard, matching the launched ROS 2 bridge node.
- Publish phone sensor values using editable identifiers.
- Subscribe to identifiers and show incoming values.

This client does not try to speak ROS 2 DDS directly from the phone. Instead, it uses bridge transports such as MQTT, WebSocket, or Redis, and the ROS 2 bridge node translates those payloads into ROS topics.

## Suggested Connection Methods

Recommended order:

1. MQTT: best first mobile transport, easy across Wi-Fi and cloud brokers.
2. WebSocket: good future option for a direct bridge gateway.
3. Redis: useful for lab/local networks, but less natural for mobile apps.

## Example Flow

1. Open connection page.
2. Choose transport, host/broker, connection id, and `domainId`.
3. Connect.
4. Open sensors page.
5. Enable sensors and edit identifiers, for example:
   - `phone.accelerometer`
   - `phone.gyroscope`
   - `phone.location`
   - `phone.light`
   - `phone.camera.frame`
6. Open subscribe page to listen for values from ROS 2 or other devices.

## Current Status

This folder is a scaffold that can be moved out into its own Flutter package later. It includes:

- Core Dart interfaces.
- Domain ID validation.
- MQTT handler shape.
- Sensor catalog with editable default identifiers.
- Example Flutter app screens for connection, sensors, and subscriptions.

The MQTT/WebSocket/Redis network internals are intentionally adapter-shaped placeholders until package choices are finalized.
