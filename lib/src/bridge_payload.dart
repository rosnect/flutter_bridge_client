// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

/// Wire value types used by ros2embedded JSON data envelopes.
enum BridgeValueType {
  boolValue,
  int32,
  uint32,
  int64,
  uint64,
  float32,
  float64,
  string,
  bytes,
  json,
}

/// An identifier, logical domain, typed value and optional acquisition timestamp.
class BridgePayload {
  /// Creates a payload. [value] must match [valueType] at the host bridge.
  const BridgePayload({
    required this.identifier,
    required this.domainId,
    required this.valueType,
    required this.value,
    this.timestamp,
  });

  /// Exact logical identifier associated with a configured ROS binding.
  final String identifier;

  /// Logical routing domain.
  final int domainId;

  /// Encoding/type of [value].
  final BridgeValueType valueType;

  /// Application value or structured native-sensor JSON object.
  final Object value;

  /// Optional measurement timestamp, serialized as Unix milliseconds.
  final DateTime? timestamp;

  /// Serializes the existing snake_case JSON envelope.
  Map<String, Object?> toJson() {
    return {
      'identifier': identifier,
      'domain_id': domainId,
      'value_type': valueType.name,
      'value': value,
      'timestamp_unix_ms': timestamp?.millisecondsSinceEpoch,
    };
  }

  /// Decodes an envelope; malformed fields or unknown types throw.
  static BridgePayload fromJson(Map<String, Object?> json) {
    return BridgePayload(
      identifier: json['identifier'] as String,
      domainId: json['domain_id'] as int,
      valueType: BridgeValueType.values.byName(json['value_type'] as String),
      value: json['value'] as Object,
      timestamp: json['timestamp_unix_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              json['timestamp_unix_ms'] as int),
    );
  }
}
