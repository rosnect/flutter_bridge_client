// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'live_sensors.dart';
import 'sensor_page.dart';
import 'sensor_presentation.dart';
import 'rosnect_style.dart';
import 'startup_splash.dart';
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
  final _appearance = AppearanceController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _live.addListener(_refresh);
    _appearance.addListener(_refresh);
    _appearance.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _live.removeListener(_refresh);
    _live.dispose();
    _session.dispose();
    _appearance.removeListener(_refresh);
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppearanceScope(
        controller: _appearance,
        child: MaterialApp(
          title: 'rosnect',
          debugShowCheckedModeBanner: false,
          theme: rosnectTheme(Brightness.light),
          darkTheme: rosnectTheme(Brightness.dark),
          themeMode: _appearance.mode,
          home: StartupSplash(
              child: AnimatedBuilder(
            animation: _session,
            builder: (context, _) => Scaffold(
              appBar: AppBar(
                title: Row(children: [
                  const RosnectLogo(),
                  const SizedBox(width: 10),
                  const Flexible(
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('rosnect',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -1.4)))),
                ]),
                actions: [
                  ConnectionIndicator(session: _session),
                  const SizedBox(width: 4),
                  const ThemeToggle(),
                  const SizedBox(width: 6),
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
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: const [
                  NavigationDestination(
                      icon: RosnectGlyph('connection', size: 24),
                      label: 'Connections'),
                  NavigationDestination(
                      icon: RosnectGlyph('sensors', size: 24),
                      label: 'Sensors'),
                  NavigationDestination(
                      icon: RosnectGlyph('subscribe', size: 24),
                      label: 'Subscribe'),
                ],
              ),
            ),
          )),
        ));
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
      child: StatusPill(label, active: session.isConnected),
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
          const PageHeading(
              index: '01',
              title: 'connections',
              subtitle: 'A direct line to your ROS world.'),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _ConnectionTile(
                    glyph: 'connection',
                    label: 'TRANSPORT',
                    value: 'mqtt',
                    footer: session.isConnected
                        ? 'Broker online'
                        : 'Ready to connect',
                    active: session.isConnected)),
            const SizedBox(width: 12),
            Expanded(
                child: _ConnectionTile(
                    glyph: 'subscribe',
                    label: 'SECURITY',
                    value: _tls ? 'encrypted' : 'local',
                    footer: _tls ? 'TLS / 8883' : 'TCP / 1883')),
          ]),
          const SizedBox(height: 20),
          Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const RosnectGlyph('connection'),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('broker setup',
                        style: Theme.of(context).textTheme.titleLarge)),
                const SizedBox(width: 10),
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
                isExpanded: true,
                value: _tls,
                decoration: const InputDecoration(
                    labelText: 'Connection security / port'),
                items: const [
                  DropdownMenuItem(
                      value: false,
                      child: Text('Normal · 1883',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: true,
                      child: Text('SSL / TLS · 8883',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
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
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Text(
                  'ONE ACTIVE CONNECTION / Enable your sources in Sensors once connected.',
                  style: Theme.of(context).textTheme.labelSmall)),
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

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile(
      {required this.glyph,
      required this.label,
      required this.value,
      required this.footer,
      this.active = false});
  final String glyph, label, value, footer;
  final bool active;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                RosnectGlyph(glyph, size: 22),
                const Spacer(),
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? const Color(0xff32956f)
                            : Theme.of(context).colorScheme.outline))
              ]),
              const SizedBox(height: 16),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(footer, style: Theme.of(context).textTheme.labelSmall),
            ],
          )));
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
        const PageHeading(
            index: '03',
            title: 'subscribe',
            subtitle: 'Listen to the other side. One channel at a time.'),
        const SizedBox(height: 20),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const RosnectGlyph('subscribe'),
                        const SizedBox(width: 12),
                        Text('new channel',
                            style: Theme.of(context).textTheme.titleLarge)
                      ]),
                      const SizedBox(height: 20),
                      TextField(
                          controller: _identifier,
                          decoration: const InputDecoration(
                              labelText: 'Identifier to subscribe')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<BridgeValueType>(
                          value: _type,
                          decoration: const InputDecoration(
                              labelText: 'Expected value type'),
                          items: [
                            for (final type in BridgeValueType.values)
                              DropdownMenuItem(
                                  value: type, child: Text(type.name))
                          ],
                          onChanged: (v) => setState(
                              () => _type = v ?? BridgeValueType.string)),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed: () => widget.live.addSubscription(
                                  _identifier.text.trim(), _type),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add subscription'))),
                    ]))),
        if (widget.live.globalError != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(widget.live.globalError!)),
        const SizedBox(height: 24),
        Row(children: [
          Text('YOUR CHANNELS', style: Theme.of(context).textTheme.labelSmall),
          const Spacer(),
          StatusPill('${widget.live.subscriptions.length} channels')
        ]),
        const SizedBox(height: 12),
        if (widget.live.subscriptions.isEmpty)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const RosnectGlyph('subscribe', size: 36),
                    const SizedBox(height: 12),
                    Text('Quiet for now.',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    const Text('Add an identifier to receive data from ROS.',
                        textAlign: TextAlign.center),
                  ])))
        else
          GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 200 +
                      (MediaQuery.textScalerOf(context).scale(14) - 14) * 5),
              children: [
                for (final entry in widget.live.subscriptions.entries)
                  Card(
                      child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _open(entry.key, entry.value),
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const RosnectGlyph('subscribe', size: 24),
                                const Spacer(),
                                IconButton(
                                    tooltip: 'Remove ${entry.key}',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => widget.live
                                        .removeSubscription(entry.key))
                              ]),
                              const SizedBox(height: 6),
                              Text(entry.key,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const Spacer(),
                              Text(entry.value.name.toUpperCase(),
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              const SizedBox(height: 6),
                              const Text('Tap to view →',
                                  style: TextStyle(fontSize: 11)),
                            ])),
                  ))
              ]),
        const SizedBox(height: 16),
        Text(
            'Channels become ROS command topics after interface acknowledgement.',
            style: Theme.of(context).textTheme.labelSmall),
      ]);
  void _open(String identifier, BridgeValueType type) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
                child: Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 8, 24, 32 + MediaQuery.viewInsetsOf(context).bottom),
              child: AnimatedBuilder(
                  animation: widget.live,
                  builder: (context, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INCOMING / ${type.name.toUpperCase()}',
                                style: Theme.of(context).textTheme.labelSmall),
                            const SizedBox(height: 12),
                            Text(identifier,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 20),
                            ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxHeight:
                                        MediaQuery.sizeOf(context).height *
                                            .45),
                                child: SingleChildScrollView(
                                    child: widget.live.session.client == null
                                        ? const Text('Connect first')
                                        : _SubscriptionValue(
                                            client: widget.live.session.client!,
                                            identifier: identifier))),
                            const SizedBox(height: 20),
                            if (widget.live.interfaces.topicFor(identifier) !=
                                null)
                              SelectableText(
                                  widget.live.interfaces.topicFor(identifier)!,
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                          ])),
            )));
  }
}

class _SubscriptionValue extends StatefulWidget {
  const _SubscriptionValue({required this.client, required this.identifier});
  final BridgeClient client;
  final String identifier;
  @override
  State<_SubscriptionValue> createState() => _SubscriptionValueState();
}

class _SubscriptionValueState extends State<_SubscriptionValue> {
  late Stream<BridgePayload> _stream;
  @override
  void initState() {
    super.initState();
    _stream = widget.client.subscribe(widget.identifier);
  }

  @override
  void didUpdateWidget(covariant _SubscriptionValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client ||
        oldWidget.identifier != widget.identifier) {
      _stream = widget.client.subscribe(widget.identifier);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<BridgePayload>(
      stream: _stream,
      builder: (context, snapshot) => SelectableText(
          snapshot.hasData
              ? formatDisplayValue(snapshot.data!.value)
              : 'Waiting for data',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontFamily: 'monospace')));
}
