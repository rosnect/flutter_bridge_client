// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosnect/live_sensors.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';

void main() {
  test('magnetic microtesla and pressure hPa are converted to ROS SI units',
      () {
    final magnetic =
        sensorRosValue(PhoneSensorKind.magnetometer, [20.0, -30.0, 40.0], 1234);
    expect((magnetic['magnetic_field'] as Map)['x'], closeTo(20e-6, 1e-12));
    final pressure = sensorRosValue(PhoneSensorKind.barometer, [1013.25], 1234);
    expect(pressure['fluid_pressure'], 101325.0);
    expect(
        (pressure['header'] as Map)['stamp'], {'sec': 1, 'nanosec': 234000000});
  });
  test('separate IMU sources explicitly mark unmeasured components', () {
    final acceleration =
        sensorRosValue(PhoneSensorKind.accelerometer, [0.0, 0.0, 9.81], 0);
    expect((acceleration['orientation_covariance'] as List).first, -1);
    expect((acceleration['angular_velocity_covariance'] as List).first, -1);
    expect((acceleration['linear_acceleration'] as Map)['z'], 9.81);
    final gyro = sensorRosValue(PhoneSensorKind.gyroscope, [1.0, 2.0, 3.0], 0);
    expect((gyro['linear_acceleration_covariance'] as List).first, -1);
  });
  test('camera bytes survive JSON and use an optical frame', () {
    final bytes = Uint8List.fromList([255, 216, 0, 127, 255, 217]);
    final frame = sensorRosValue(PhoneSensorKind.camera, bytes, 1234);
    final wire = jsonDecode(jsonEncode(frame)) as Map;
    expect(base64Decode(wire['data_base64'] as String), bytes);
    expect((wire['header'] as Map)['frame_id'], 'phone_camera_optical');
  });
  test('GPS does not invent unavailable altitude or covariance', () {
    final fix = sensorRosValue(
        PhoneSensorKind.location,
        {
          'latitude': 52.0,
          'longitude': 13.0,
          'accuracy': 10.0,
          'provider': 'network'
        },
        0);
    expect(fix.containsKey('altitude'), false);
    expect(fix['position_covariance_type'], 0);
  });
}
