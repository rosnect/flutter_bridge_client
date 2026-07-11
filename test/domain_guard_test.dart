import 'package:flutter_test/flutter_test.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';

void main() {
  test('connection config rejects negative domain id', () {
    const config = ConnectionConfig(
      connectionId: 'phone',
      domainId: -1,
      transport: BridgeTransport.mqtt,
      host: 'localhost',
    );

    expect(config.validate, throwsArgumentError);
  });

  test('client writes with configured domain id', () async {
    final handler = MqttBridgeConnectionHandler();
    final client = BridgeClient(handler);
    await client.connect(
      const ConnectionConfig(
        connectionId: 'phone',
        domainId: 7,
        transport: BridgeTransport.mqtt,
        host: 'localhost',
      ),
    );

    await client.writeData('phone.accelerometer', {'x': 0.0});
    expect(client.domainId, 7);
  });
}
