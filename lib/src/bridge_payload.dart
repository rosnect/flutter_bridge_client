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

class BridgePayload {
  const BridgePayload({
    required this.identifier,
    required this.domainId,
    required this.valueType,
    required this.value,
    this.timestamp,
  });

  final String identifier;
  final int domainId;
  final BridgeValueType valueType;
  final Object value;
  final DateTime? timestamp;

  Map<String, Object?> toJson() {
    return {
      'identifier': identifier,
      'domain_id': domainId,
      'value_type': valueType.name,
      'value': value,
      'timestamp_unix_ms': timestamp?.millisecondsSinceEpoch,
    };
  }

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
