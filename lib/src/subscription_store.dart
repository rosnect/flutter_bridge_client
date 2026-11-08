// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

/// Immutable display and selection state for one incoming identifier.
class BridgeSubscription {
  /// Creates a subscription selection.
  const BridgeSubscription({
    required this.identifier,
    this.displayName,
    this.enabled = true,
  });

  /// Exact logical identifier to receive.
  final String identifier;

  /// Optional label for the application UI.
  final String? displayName;

  /// Whether the application intends to receive this identifier.
  final bool enabled;

  /// Copies the selection with replacement values.
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

/// In-memory selections; this does not open MQTT subscriptions or persist data.
class SubscriptionStore {
  final List<BridgeSubscription> _items = [];

  /// An unmodifiable view of the current selections.
  List<BridgeSubscription> get items => List.unmodifiable(_items);

  /// Adds a nonempty identifier and optional display label.
  void add(String identifier, {String? displayName}) {
    if (identifier.trim().isEmpty) {
      throw ArgumentError.value(identifier, 'identifier', 'must not be empty');
    }
    _items.add(
        BridgeSubscription(identifier: identifier, displayName: displayName));
  }

  /// Removes all selections matching the identifier.
  void remove(String identifier) {
    _items.removeWhere((item) => item.identifier == identifier);
  }
}
