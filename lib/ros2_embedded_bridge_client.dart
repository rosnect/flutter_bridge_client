// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

/// Flutter-native MQTT transport and interface discovery for ros2embedded.
///
/// Use [ConnectionSession] and [DeviceInterfaces] to keep broker connectivity
/// separate from acknowledged ROS interface readiness. Hardware capture is
/// implemented by the separate Rosnect application, not by this library.
library ros2_embedded_bridge_client;

export 'src/bridge_client.dart';
export 'src/bridge_connection.dart';
export 'src/bridge_payload.dart';
export 'src/connection_config.dart';
export 'src/sensor_catalog.dart';
export 'src/subscription_store.dart';
export 'src/connection_session.dart';
export 'src/device_interfaces.dart';
