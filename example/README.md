# Minimal connection example

This example advertises one outgoing String status and one incoming String
command through the existing ros2embedded MQTT device-configuration protocol.
It does not access phone hardware or connect until you press Connect.

From this directory, generate platform runner files if needed:

```sh
flutter create --platforms=android,ios,linux,macos,windows .
flutter pub get
flutter run
```

Enter a broker hostname/IP reachable from the device. `localhost` refers to the
device running the app, not a different development computer. Start an existing
ros2embedded bridge in MQTT device mode for connection `flutter_demo`, logical
domain 7, using the same broker. The UI waits for the matching configuration ACK
before enabling Publish status. Give each concurrent device a distinct
connection ID.

For the full phone UI and Android sensor capture, use the separate `rosnect/`
application in the source repository.
