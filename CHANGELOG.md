## 0.1.0

- Initial public package release under the Apache License, Version 2.0.
- MQTT 3.1.1 connections with optional credentials, verified TLS, private CA
  certificates and mutual TLS client certificates.
- Typed JSON payloads with identifier/domain routing and timestamp preservation.
- Single active connection ownership and replacement handling.
- Device-advertised interface snapshots, matching acknowledgements, retries,
  configuration requests and normalized ROS topic discovery.
- Flutter-friendly connection/interface state and subscription/sensor models.
- Runnable connection example and separate Rosnect Android sensor application
  available in the source repository.

Only MQTT is implemented. WebSocket/Redis transports and browser support are not
provided. Native sensor capture belongs to the separate Android application,
not to this client library.
