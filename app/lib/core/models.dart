class Txn {
  const Txn({
    required this.id,
    required this.type,
    required this.direction,
    required this.amountHalalas,
    required this.occurredAt,
    this.merchant,
    this.isInternal = false,
  });

  final String id;
  final String type;
  final String direction; // 'in' | 'out'
  final int amountHalalas;
  final DateTime occurredAt;
  final String? merchant;
  final bool isInternal;

  bool get isIncoming => direction == 'in';

  factory Txn.fromRow(Map<String, dynamic> r) => Txn(
    id: r['id'] as String,
    type: r['type'] as String,
    direction: r['direction'] as String,
    amountHalalas: (r['amount_halalas'] as num).toInt(),
    occurredAt: DateTime.parse(r['occurred_at'] as String).toUtc(),
    merchant: r['merchant_raw'] as String?,
    isInternal: (r['is_internal'] as bool?) ?? false,
  );
}

class RawMessage {
  const RawMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
  });

  final String id;
  final String sender;
  final String body;
  final DateTime receivedAt;

  factory RawMessage.fromRow(Map<String, dynamic> r) => RawMessage(
    id: r['id'] as String,
    sender: r['sender'] as String,
    body: r['body'] as String,
    receivedAt: DateTime.parse(r['received_at'] as String).toUtc(),
  );
}

class SenderGap {
  const SenderGap({required this.sender, required this.lastReceivedAt});
  final String sender;
  final DateTime lastReceivedAt;
}

/// What the user typed when adding or converting a transaction by hand.
class ManualTxn {
  const ManualTxn({
    required this.direction,
    required this.amountHalalas,
    required this.occurredAt,
    this.merchant,
  });

  final String direction;
  final int amountHalalas;
  final DateTime occurredAt;
  final String? merchant;
}
