import 'package:flutter/material.dart';
import 'live_sensors.dart';
import 'package:ros2_embedded_bridge_client/ros2_embedded_bridge_client.dart';

void main() => runApp(const RosnectApp());

class RosnectApp extends StatefulWidget {
  const RosnectApp({super.key});
  @override
  State<RosnectApp> createState() => _RosnectAppState();
}

class _RosnectAppState extends State<RosnectApp> {
  final _session = ConnectionSession();
  late final LiveSensors _live = LiveSensors(_session);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _live.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _live.removeListener(_refresh);
    _live.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rosnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff007f82)),
        useMaterial3: true,
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: AnimatedBuilder(
        animation: _session,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Row(children: [
              Image.asset('assets/dark_rosnect.png', height: 36, width: 36),
              const SizedBox(width: 10),
              const Text('Rosnect'),
            ]),
            actions: [
              ConnectionIndicator(session: _session),
              const SizedBox(width: 16),
            ],
          ),
          body: SafeArea(
            child: IndexedStack(
              index: _index,
              children: [
                ConnectionsPage(session: _session),
                SensorPage(live: _live),
                SubscribePage(live: _live),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.settings_ethernet), label: 'Connections'),
              NavigationDestination(
                  icon: Icon(Icons.sensors), label: 'Sensors'),
              NavigationDestination(
                  icon: Icon(Icons.topic), label: 'Subscribe'),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({required this.session, super.key});
  final ConnectionSession session;

  @override
  Widget build(BuildContext context) {
    final label = session.busy
        ? 'Connecting…'
        : session.isConnected
            ? 'Connected'
            : 'Disconnected';
    return Semantics(
      label: 'Broker status: $label',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle,
            size: 10,
            color: session.busy
                ? Colors.orange
                : session.isConnected
                    ? Colors.green
                    : Colors.grey),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ]),
    );
  }
}

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({required this.session, super.key});
  final ConnectionSession session;
  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  final _form = GlobalKey<FormState>();
  final _host = TextEditingController(text: '192.168.0.81');
  final _connectionId = TextEditingController(text: 'phone_1');
  final _domainId = TextEditingController(text: '7');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _ca = TextEditingController();
  final _certificate = TextEditingController();
  final _key = TextEditingController();
  final _keyPassword = TextEditingController();
  bool _tls = false;
  bool _showPassword = false;
  bool _clientCertificate = false;

  @override
  void dispose() {
    for (final controller in [
      _host,
      _connectionId,
      _domainId,
      _username,
      _password,
      _ca,
      _certificate,
      _key,
      _keyPassword
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController field) =>
      field.text.trim().isEmpty ? null : field.text.trim();

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Connections',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text(
              'One active connection at a time. Connecting replaces the current connection.'),
          const SizedBox(height: 16),
          const Text(
              'After connecting, enable sensors in Sensors. ROS interfaces must be acknowledged before data streams.'),
          const SizedBox(height: 8),
          Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.router_outlined),
                const SizedBox(width: 10),
                Text('MQTT broker',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Icon(Icons.circle,
                    size: 12,
                    color: session.isConnected ? Colors.green : Colors.grey),
              ]),
              if (session.config != null) ...[
                const SizedBox(height: 8),
                Text(
                    '${session.config!.host}:${session.config!.effectivePort}'),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _host,
                decoration: const InputDecoration(
                    labelText: 'Broker address', hintText: '192.168.0.81'),
                autocorrect: false,
                validator: (value) => value == null ||
                        value.trim().isEmpty ||
                        value.contains('://') ||
                        value.contains('/')
                    ? 'Enter a hostname or IP without mqtt:// or a port.'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<bool>(
                value: _tls,
                decoration: const InputDecoration(
                    labelText: 'Connection security / port'),
                items: const [
                  DropdownMenuItem(value: false, child: Text('Normal · 1883')),
                  DropdownMenuItem(
                      value: true, child: Text('SSL / TLS · 8883')),
                ],
                onChanged: session.busy
                    ? null
                    : (value) => setState(() => _tls = value ?? false),
              ),
              const SizedBox(height: 14),
              TextFormField(
                  controller: _username,
                  autocorrect: false,
                  decoration:
                      const InputDecoration(labelText: 'Username (optional)')),
              const SizedBox(height: 14),
              TextFormField(
                  controller: _password,
                  obscureText: !_showPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                      labelText: 'Password (optional)',
                      suffixIcon: IconButton(
                        tooltip:
                            _showPassword ? 'Hide password' : 'Show password',
                        icon: Icon(_showPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ))),
              if (_tls) ...[
                const SizedBox(height: 14),
                const Text(
                    'TLS verifies the broker certificate using system trusted authorities. For a private broker, paste its CA certificate below. The broker hostname or IP must match its certificate.'),
                const SizedBox(height: 14),
                TextFormField(
                    controller: _ca,
                    minLines: 3,
                    maxLines: 6,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        labelText: 'CA certificate PEM (optional)',
                        alignLabelWithHint: true)),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Client certificate (mutual TLS)'),
                    value: _clientCertificate,
                    onChanged: (value) =>
                        setState(() => _clientCertificate = value)),
                if (_clientCertificate) ...[
                  TextFormField(
                      controller: _certificate,
                      minLines: 3,
                      maxLines: 6,
                      autocorrect: false,
                      decoration: const InputDecoration(
                          labelText: 'Client certificate PEM',
                          alignLabelWithHint: true),
                      validator: (value) => _tls &&
                              _clientCertificate &&
                              (value?.trim().isEmpty ?? true)
                          ? 'Client certificate is required.'
                          : null),
                  const SizedBox(height: 14),
                  TextFormField(
                      controller: _key,
                      minLines: 3,
                      maxLines: 6,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                          labelText: 'Client private key PEM',
                          alignLabelWithHint: true),
                      validator: (value) => _tls &&
                              _clientCertificate &&
                              (value?.trim().isEmpty ?? true)
                          ? 'Client private key is required.'
                          : null),
                  const SizedBox(height: 14),
                  TextFormField(
                      controller: _keyPassword,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                          labelText: 'Private key password (optional)')),
                ],
              ],
              const SizedBox(height: 14),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Bridge settings'),
                children: [
                  TextFormField(
                      controller: _connectionId,
                      decoration:
                          const InputDecoration(labelText: 'Connection ID'),
                      validator: (value) =>
                          RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(value ?? '')
                              ? null
                              : 'Use letters, numbers, _, - or .'),
                  const SizedBox(height: 14),
                  TextFormField(
                      controller: _domainId,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Bridge domain ID'),
                      validator: (value) {
                        final id = int.tryParse(value ?? '');
                        return id == null || id < 0 || id > 0xffffffff
                            ? 'Enter a domain ID from 0 to 4294967295.'
                            : null;
                      }),
                  const SizedBox(height: 14),
                ],
              ),
              if (session.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(session.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: session.busy ? null : _connect,
                  icon: session.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.link),
                  label: Text(session.busy
                      ? 'Connecting…'
                      : session.isConnected
                          ? 'Reconnect'
                          : 'Connect'),
                ),
                OutlinedButton.icon(
                  onPressed: session.busy || !session.isConnected
                      ? null
                      : session.disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
              ]),
            ]),
          )),
          const SizedBox(height: 12),
          const ListTile(
              leading: Icon(Icons.extension_outlined),
              title: Text('More connection types'),
              subtitle: Text('WebSocket and Redis are not available yet.')),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    await widget.session.connect(ConnectionConfig(
      connectionId: _connectionId.text.trim(),
      domainId: int.parse(_domainId.text),
      transport: BridgeTransport.mqtt,
      host: _host.text.trim(),
      port: _tls ? 8883 : 1883,
      useTls: _tls,
      username: _optional(_username),
      password: _password.text.isEmpty ? null : _password.text,
      caCertificate: _tls ? _optional(_ca) : null,
      clientCertificate:
          _tls && _clientCertificate ? _optional(_certificate) : null,
      clientPrivateKey: _tls && _clientCertificate ? _optional(_key) : null,
      privateKeyPassword:
          _tls && _clientCertificate && _keyPassword.text.isNotEmpty
              ? _keyPassword.text
              : null,
    ));
  }
}

class SensorPage extends StatelessWidget {
  const SensorPage({required this.live, super.key});
  final LiveSensors live;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Live phone sensors',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(!live.session.isConnected
              ? 'Connect to your MQTT broker first.'
              : live.interfaces.ready
                  ? 'ROS interfaces ready · streaming enabled sensors'
                  : 'Waiting for ROS bridge to accept the sensor interfaces…'),
          if (live.interfaces.error != null)
            Text(live.interfaces.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (live.globalError != null) Text(live.globalError!),
          Wrap(spacing: 12, children: [
            TextButton.icon(
                onPressed:
                    live.session.isConnected ? live.interfaces.resync : null,
                icon: const Icon(Icons.sync),
                label: const Text('Retry ROS setup')),
            TextButton.icon(
                onPressed: live.settings,
                icon: const Icon(Icons.settings),
                label: const Text('App permissions')),
          ]),
          const Text(
              'Capture pauses when the app is backgrounded or the screen locks. Enable each source to share it.'),
          for (final item in live.sensors.values)
            _SensorCard(
                key: ValueKey(item.definition.kind), live: live, item: item),
        ],
      );
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({required this.live, required this.item, super.key});
  final LiveSensors live;
  final EnabledPhoneSensor item;
  @override
  Widget build(BuildContext context) {
    final kind = item.definition.kind;
    final supported = live.available[kind] ?? false;
    final topic = live.interfaces.topicFor(item.identifier);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.definition.name),
                    value: item.enabled,
                    subtitle: Text(supported
                        ? item.definition.description
                        : 'Unavailable on this device'),
                    onChanged:
                        supported ? (value) => live.enable(kind, value) : null),
                TextFormField(
                    initialValue: item.identifier,
                    decoration: const InputDecoration(
                        labelText: 'Identifier (submit to apply)'),
                    onFieldSubmitted: (value) =>
                        live.rename(kind, value.trim())),
                const SizedBox(height: 8),
                Text(sensorMessageTypes[kind]!,
                    style: Theme.of(context).textTheme.labelSmall),
                if (topic != null)
                  SelectableText(topic,
                      style: Theme.of(context).textTheme.labelSmall),
                if (live.errors[kind] != null)
                  Text(live.errors[kind]!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (item.enabled && live.latest.containsKey(kind))
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                          'Sent ${live.sent[kind] ?? 0} · ${live.latest[kind]}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis)),
                if (kind == PhoneSensorKind.camera && item.enabled) ...[
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<bool>(
                            value: live.frontCamera,
                            decoration:
                                const InputDecoration(labelText: 'Camera'),
                            items: const [
                              DropdownMenuItem(
                                  value: false, child: Text('Rear')),
                              DropdownMenuItem(
                                  value: true, child: Text('Front'))
                            ],
                            onChanged: (v) => live.cameraOptions(front: v))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: DropdownButtonFormField<int>(
                            value: live.cameraFps,
                            decoration: const InputDecoration(
                                labelText: 'Frames / second'),
                            items: [
                              for (final n in [1, 2, 5])
                                DropdownMenuItem(
                                    value: n, child: Text('$n FPS'))
                            ],
                            onChanged: (v) => live.cameraOptions(fps: v))),
                  ]),
                  const SizedBox(height: 8),
                  if (live.cameraPreview != null)
                    Image.memory(live.cameraPreview!,
                        gaplessPlayback: true,
                        height: 220,
                        fit: BoxFit.contain),
                  const Text(
                      'JPEG up to 640 × 640 · quality 55 · default 2 FPS'),
                ],
                if (kind == PhoneSensorKind.touch && item.enabled)
                  SizedBox(
                      height: 160,
                      child: LayoutBuilder(
                          builder: (context, constraints) => GestureDetector(
                              onPanStart: (e) => live.touch(
                                  e.localPosition, constraints.biggest, 'down'),
                              onPanUpdate: (e) => live.touch(
                                  e.localPosition, constraints.biggest, 'move'),
                              onPanEnd: (_) => live.touch(
                                  Offset.zero, constraints.biggest, 'up'),
                              onTapDown: (e) => live.touch(
                                  e.localPosition, constraints.biggest, 'tap'),
                              child: Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  alignment: Alignment.center,
                                  child: const Text(
                                      'Touch or drag here to publish coordinates'))))),
              ],
            )));
  }
}

class SubscribePage extends StatefulWidget {
  const SubscribePage({required this.live, super.key});
  final LiveSensors live;
  @override
  State<SubscribePage> createState() => _SubscribePageState();
}

class _SubscribePageState extends State<SubscribePage> {
  final _identifier = TextEditingController(text: 'robot.status');
  BridgeValueType _type = BridgeValueType.string;
  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Subscriptions become ROS command topics after bridge acknowledgement.'),
        const SizedBox(height: 12),
        TextField(
            controller: _identifier,
            decoration:
                const InputDecoration(labelText: 'Identifier to subscribe')),
        const SizedBox(height: 12),
        DropdownButtonFormField<BridgeValueType>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Expected value type'),
            items: [
              for (final type in BridgeValueType.values)
                DropdownMenuItem(value: type, child: Text(type.name))
            ],
            onChanged: (v) =>
                setState(() => _type = v ?? BridgeValueType.string)),
        FilledButton.icon(
            onPressed: () =>
                widget.live.addSubscription(_identifier.text.trim(), _type),
            icon: const Icon(Icons.add),
            label: const Text('Add subscription')),
        if (widget.live.globalError != null) Text(widget.live.globalError!),
        for (final entry in widget.live.subscriptions.entries)
          ListTile(
              title: Text('${entry.key} · ${entry.value.name}'),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.live.interfaces.topicFor(entry.key) != null)
                      SelectableText(
                          widget.live.interfaces.topicFor(entry.key)!),
                    if (widget.live.session.client == null)
                      const Text('Connect first')
                    else
                      _SubscriptionValue(
                          client: widget.live.session.client!,
                          identifier: entry.key),
                  ]),
              trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => widget.live.removeSubscription(entry.key))),
      ]);
}

class _SubscriptionValue extends StatelessWidget {
  const _SubscriptionValue({required this.client, required this.identifier});
  final BridgeClient client;
  final String identifier;
  @override
  Widget build(BuildContext context) => StreamBuilder<BridgePayload>(
      stream: client.subscribe(identifier),
      builder: (context, snapshot) => Text(
          snapshot.hasData ? '${snapshot.data!.value}' : 'Waiting for data'));
}
