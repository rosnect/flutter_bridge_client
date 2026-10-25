# Rosnect

Rosnect mobile app (real sensor capture currently Android-only) for the Flutter ROS2 Embedded Bridge Client. See [the package README](../README.md) for connection settings, MQTT topics, testing and build instructions.

The Sensors screen uses two columns of compact tiles. Switches control sharing; tap a tile to open its readings, 30-second time-series graph, camera preview or touch pad. Motion plots show X/Y/Z together. GPS, battery and microphone graphs offer a measurement selector. ROS identifiers and topics are under Sensor settings.

Displayed measurements use four significant digits, with six decimal places for GPS coordinates. This formatting does not round outgoing ROS payloads. Plot history is bounded to 30 seconds and 600 samples per sensor.

Appearance: use the sun/moon toggle in the header to switch between light and dark themes. The selected theme is remembered on Android. Rosnect uses original geometric icons, a circular logo that inverts for the light theme, and a lowercase wordmark. Connections, Sensors and Subscribe share the same monochrome card layout.

Inside motion/touch details, the axis chips independently select X/Y/Z (X/Y for touch). Any combination, including all hidden, is supported; All axes restores every line. Axis colors stay consistent when isolating a line. These controls only affect the on-screen graph and readings; all enabled sensor data continues to reach ROS.
