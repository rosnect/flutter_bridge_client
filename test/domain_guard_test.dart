import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';

class FakeHandler implements BridgeConnectionHandler {
  final events = <String>[];
  final incoming = StreamController<BridgePayload>.broadcast();
  final status = StreamController<BridgeConnectionStatus>.broadcast();
  final sent = <BridgePayload>[];
  bool fail = false;
  @override
  bool isConnected = false;
  @override
  Stream<BridgePayload> get messages => incoming.stream;
  @override
  Stream<BridgeConnectionStatus> get connectionChanges => status.stream;
  @override
  Future<void> connect(ConnectionConfig config) async {
    events.add('connect');
    if (fail) throw StateError('Rejected');
    isConnected = true;
    status.add(BridgeConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    events.add('disconnect');
    isConnected = false;
    status.add(BridgeConnectionStatus.disconnected);
  }

  @override
  Future<void> send(BridgePayload payload) async => sent.add(payload);
}

ConnectionConfig config(
        {int domain = 7, bool tls = false, String? cert, String? key}) =>
    ConnectionConfig(
      connectionId: 'phone',
      domainId: domain,
      transport: BridgeTransport.mqtt,
      host: 'localhost',
      useTls: tls,
      clientCertificate: cert,
      clientPrivateKey: key,
    );

void main() {
  test('domain is a protobuf uint32', () {
    expect(config(domain: -1).validate, throwsArgumentError);
    expect(config(domain: 0x100000000).validate, throwsArgumentError);
    config(domain: 0xffffffff).validate();
  });
  test('TLS uses its own port and requires matching client key/certificate',
      () {
    expect(config().effectivePort, 1883);
    expect(config(tls: true).effectivePort, 8883);
    expect(config(tls: true, cert: 'cert').validate, throwsArgumentError);
  });
  test('write uses configured domain and rejects sending after connection loss',
      () async {
    final handler = FakeHandler();
    final client = BridgeClient(handler);
    await client.connect(config());
    await client.writeData('phone.accelerometer', {'x': 0.0});
    expect(handler.sent.single.domainId, 7);
    handler.isConnected = false;
    expect(() => client.writeData('test', 1), throwsStateError);
  });
  test('incoming wrong domains are filtered', () async {
    final handler = FakeHandler();
    final client = BridgeClient(handler);
    await client.connect(config());
    final received = <BridgePayload>[];
    final subscription = client.subscribe('status').listen(received.add);
    for (final domain in [8, 7]) {
      handler.incoming.add(BridgePayload(
          identifier: 'status',
          domainId: domain,
          valueType: BridgeValueType.string,
          value: 'ok'));
    }
    await Future<void>.delayed(Duration.zero);
    expect(received.map((e) => e.domainId), [7]);
    await subscription.cancel();
  });
  test('replacement disconnects previous connection before opening another',
      () async {
    final first = FakeHandler();
    final second = FakeHandler();
    var count = 0;
    final session = ConnectionSession(factory: (_) {
      if (count++ == 0) return first;
      expect(first.isConnected, false);
      return second;
    });
    await session.connect(config());
    expect(session.isConnected, true);
    await session.connect(config(tls: true));
    expect(first.events, ['connect', 'disconnect']);
    expect(second.isConnected, true);
    await session.disconnect();
    expect(session.isConnected, false);
    session.dispose();
  });
  test('failed replacement leaves no active connection', () async {
    final first = FakeHandler();
    final second = FakeHandler()..fail = true;
    var count = 0;
    final session =
        ConnectionSession(factory: (_) => count++ == 0 ? first : second);
    await session.connect(config());
    await session.connect(config(tls: true));
    expect(first.isConnected, false);
    expect(session.isConnected, false);
    expect(session.client, null);
    expect(session.error, contains('Rejected'));
    session.dispose();
  });
  test('unexpected disconnect updates session indicator listeners', () async {
    final handler = FakeHandler();
    final session = ConnectionSession(factory: (_) => handler);
    await session.connect(config());
    var notified = false;
    session.addListener(() => notified = true);
    handler.isConnected = false;
    handler.status.add(BridgeConnectionStatus.disconnected);
    await Future<void>.delayed(Duration.zero);
    expect(notified, true);
    expect(session.isConnected, false);
    session.dispose();
  });
  test('unimplemented transports cannot report successful connections', () {
    expect(() => createBridgeConnectionHandler(BridgeTransport.redis),
        throwsUnsupportedError);
    expect(() => createBridgeConnectionHandler(BridgeTransport.websocket),
        throwsUnsupportedError);
  });
}
