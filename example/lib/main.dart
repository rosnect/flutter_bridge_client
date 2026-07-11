import 'package:flutter/material.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';

void main() {
  runApp(const BridgeClientExampleApp());
}

class BridgeClientExampleApp extends StatefulWidget {
  const BridgeClientExampleApp({super.key});

  @override
  State<BridgeClientExampleApp> createState() => _BridgeClientExampleAppState();
}

class _BridgeClientExampleAppState extends State<BridgeClientExampleApp> {
  BridgeClient? _client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROS2 Bridge Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: BridgeHome(
        client: _client,
        onConnected: (client) => setState(() => _client = client),
      ),
    );
  }
}

class BridgeHome extends StatefulWidget {
  const BridgeHome({
    required this.client,
    required this.onConnected,
    super.key,
  });

  final BridgeClient? client;
  final ValueChanged<BridgeClient> onConnected;

  @override
  State<BridgeHome> createState() => _BridgeHomeState();
}

class _BridgeHomeState extends State<BridgeHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ConnectionPage(onConnected: widget.onConnected),
      SensorPage(client: widget.client),
      SubscribePage(client: widget.client),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('ROS2 Bridge Client')),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.settings_ethernet), label: 'Connect'),
          NavigationDestination(icon: Icon(Icons.sensors), label: 'Sensors'),
          NavigationDestination(icon: Icon(Icons.topic), label: 'Subscribe'),
        ],
      ),
    );
  }
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({required this.onConnected, super.key});

  final ValueChanged<BridgeClient> onConnected;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _connectionId = TextEditingController(text: 'phone_1');
  final _host = TextEditingController(text: '192.168.1.10');
  final _port = TextEditingController(text: '1883');
  final _domainId = TextEditingController(text: '7');
  BridgeTransport _transport = BridgeTransport.mqtt;
  String _status = 'Not connected';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<BridgeTransport>(
          value: _transport,
          decoration: const InputDecoration(labelText: 'Connection method'),
          items: const [
            DropdownMenuItem(value: BridgeTransport.mqtt, child: Text('MQTT')),
            DropdownMenuItem(
                value: BridgeTransport.websocket, child: Text('WebSocket')),
            DropdownMenuItem(
                value: BridgeTransport.redis, child: Text('Redis')),
          ],
          onChanged: (value) =>
              setState(() => _transport = value ?? BridgeTransport.mqtt),
        ),
        TextField(
          controller: _connectionId,
          decoration: const InputDecoration(labelText: 'Connection id'),
        ),
        TextField(
          controller: _host,
          decoration: const InputDecoration(labelText: 'Host / broker'),
        ),
        TextField(
          controller: _port,
          decoration: const InputDecoration(labelText: 'Port'),
          keyboardType: TextInputType.number,
        ),
        TextField(
          controller: _domainId,
          decoration: const InputDecoration(labelText: 'Domain id'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.link),
          label: const Text('Connect'),
          onPressed: _connect,
        ),
        const SizedBox(height: 12),
        Text(_status),
      ],
    );
  }

  Future<void> _connect() async {
    final config = ConnectionConfig(
      connectionId: _connectionId.text,
      domainId: int.parse(_domainId.text),
      transport: _transport,
      host: _host.text,
      port: int.tryParse(_port.text),
    );

    final client = BridgeClient(createBridgeConnectionHandler(_transport));
    await client.connect(config);
    widget.onConnected(client);
    setState(() =>
        _status = 'Connected to ${config.host} with domain ${config.domainId}');
  }
}

class SensorPage extends StatefulWidget {
  const SensorPage({required this.client, super.key});

  final BridgeClient? client;

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  late List<EnabledPhoneSensor> _sensors;

  @override
  void initState() {
    super.initState();
    _sensors = defaultSensorSelection();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sensors.length,
      itemBuilder: (context, index) {
        final item = _sensors[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: item.enabled,
                  title: Text(item.definition.name),
                  subtitle: Text(item.definition.description),
                  onChanged: (value) {
                    setState(() {
                      _sensors[index] = item.copyWith(enabled: value);
                    });
                  },
                ),
                TextFormField(
                  initialValue: item.identifier,
                  decoration: const InputDecoration(labelText: 'Identifier'),
                  onChanged: (value) {
                    _sensors[index] = item.copyWith(identifier: value);
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.upload),
                    label: const Text('Publish sample'),
                    onPressed: item.enabled ? () => _publishSample(item) : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _publishSample(EnabledPhoneSensor sensor) async {
    final client = widget.client;
    if (client == null || !client.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect first')),
      );
      return;
    }

    await client.writeData(sensor.identifier, {
      'sensor': sensor.definition.name,
      'sample': true,
      'value': 1.0,
    });
  }
}

class SubscribePage extends StatefulWidget {
  const SubscribePage({required this.client, super.key});

  final BridgeClient? client;

  @override
  State<SubscribePage> createState() => _SubscribePageState();
}

class _SubscribePageState extends State<SubscribePage> {
  final _identifier = TextEditingController(text: 'robot.status');
  final _subscriptions = SubscriptionStore();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _identifier,
                decoration:
                    const InputDecoration(labelText: 'Identifier to subscribe'),
              ),
            ),
            IconButton(
              tooltip: 'Add subscription',
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() => _subscriptions.add(_identifier.text));
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final subscription in _subscriptions.items)
          ListTile(
            leading: const Icon(Icons.topic),
            title: Text(subscription.identifier),
            subtitle: widget.client == null
                ? const Text('Connect first')
                : _SubscriptionValue(
                    client: widget.client!,
                    identifier: subscription.identifier,
                  ),
            trailing: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() => _subscriptions.remove(subscription.identifier));
              },
            ),
          ),
      ],
    );
  }
}

class _SubscriptionValue extends StatelessWidget {
  const _SubscriptionValue({
    required this.client,
    required this.identifier,
  });

  final BridgeClient client;
  final String identifier;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BridgePayload>(
      stream: client.subscribe(identifier),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('Waiting for data');
        }
        return Text(snapshot.data!.value.toString());
      },
    );
  }
}
