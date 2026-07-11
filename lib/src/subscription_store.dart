class BridgeSubscription {
  const BridgeSubscription({
    required this.identifier,
    this.displayName,
    this.enabled = true,
  });

  final String identifier;
  final String? displayName;
  final bool enabled;

  BridgeSubscription copyWith({
    String? identifier,
    String? displayName,
    bool? enabled,
  }) {
    return BridgeSubscription(
      identifier: identifier ?? this.identifier,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
    );
  }
}

class SubscriptionStore {
  final List<BridgeSubscription> _items = [];

  List<BridgeSubscription> get items => List.unmodifiable(_items);

  void add(String identifier, {String? displayName}) {
    if (identifier.trim().isEmpty) {
      throw ArgumentError.value(identifier, 'identifier', 'must not be empty');
    }
    _items.add(
        BridgeSubscription(identifier: identifier, displayName: displayName));
  }

  void remove(String identifier) {
    _items.removeWhere((item) => item.identifier == identifier);
  }
}
