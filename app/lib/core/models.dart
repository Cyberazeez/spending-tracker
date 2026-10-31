class Txn {
  const Txn({
    required this.id,
    required this.type,
    required this.direction,
    required this.amountHalalas,
    required this.occurredAt,
    this.merchant,
    this.merchantNorm,
    this.categoryId,
    this.isInternal = false,
  });

  final String id;
  final String type;
  final String direction; // 'in' | 'out'
  final int amountHalalas;
  final DateTime occurredAt;
  final String? merchant;
  final String? merchantNorm;
  final String? categoryId;
  final bool isInternal;

  bool get isIncoming => direction == 'in';

  factory Txn.fromRow(Map<String, dynamic> r) => Txn(
    id: r['id'] as String,
    type: r['type'] as String,
    direction: r['direction'] as String,
    amountHalalas: (r['amount_halalas'] as num).toInt(),
    occurredAt: DateTime.parse(r['occurred_at'] as String).toUtc(),
    merchant: r['merchant_raw'] as String?,
    merchantNorm: r['merchant_norm'] as String?,
    categoryId: r['category_id'] as String?,
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
  const SenderGap({required this.sender, this.lastReceivedAt});
  final String sender;

  /// Null when nothing has ever arrived from this sender.
  final DateTime? lastReceivedAt;
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

class Category {
  const Category({required this.id, required this.name, this.nameAr});
  final String id;
  final String name;
  final String? nameAr;

  String label({required bool arabic}) =>
      arabic && (nameAr?.isNotEmpty ?? false) ? nameAr! : name;

  factory Category.fromRow(Map<String, dynamic> r) => Category(
    id: r['id'] as String,
    name: r['name'] as String,
    nameAr: r['name_ar'] as String?,
  );
}

/// What the Transactions list is currently showing.
class TxFilter {
  const TxFilter({
    this.query = '',
    this.categoryId,
    this.uncategorizedOnly = false,
    this.hideInternal = false,
  });
  final String query;
  final String? categoryId;
  final bool uncategorizedOnly;
  final bool hideInternal;

  bool get isActive =>
      query.isNotEmpty ||
      categoryId != null ||
      uncategorizedOnly ||
      hideInternal;

  TxFilter copyWith({
    String? query,
    Object? categoryId = _keep,
    bool? uncategorizedOnly,
    bool? hideInternal,
  }) => TxFilter(
    query: query ?? this.query,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as String?,
    uncategorizedOnly: uncategorizedOnly ?? this.uncategorizedOnly,
    hideInternal: hideInternal ?? this.hideInternal,
  );

  static const _keep = Object();
}

/// One occurrence of an obligation for one period (a bill, an installment, a statement).
class ObligationInstance {
  const ObligationInstance({
    required this.id,
    required this.obligationId,
    required this.name,
    required this.kind,
    required this.dueDate,
    required this.status,
    this.periodStart,
    this.expectedHalalas,
    this.actualHalalas,
    this.transactionId,
    this.matchState = 'none',
    this.graceDays = 0,
    this.leadDays = 2,
  });

  final String id;
  final String obligationId;
  final String name;
  final String kind; // bill | fixed | loan | card_statement
  final DateTime? periodStart; // UTC midnight of a Riyadh calendar date
  final DateTime dueDate; // UTC midnight of a Riyadh calendar date
  final int? expectedHalalas;
  final int? actualHalalas;
  final String status; // pending | paid | overdue | skipped
  final String? transactionId;
  final String matchState; // auto | suggested | manual | none
  final int graceDays;
  final int leadDays;

  bool get isSuggestion => matchState == 'suggested' && status == 'pending';

  factory ObligationInstance.fromRow(Map<String, dynamic> r) {
    final ob = (r['obligations'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rule = (ob['due_rule'] as Map?)?.cast<String, dynamic>() ?? const {};
    DateTime day(String s) => DateTime.parse('${s.substring(0, 10)}T00:00:00Z');
    return ObligationInstance(
      id: r['id'] as String,
      obligationId: r['obligation_id'] as String,
      name: (ob['name'] as String?) ?? '',
      kind: (ob['kind'] as String?) ?? 'fixed',
      periodStart: r['period_start'] == null
          ? null
          : day(r['period_start'] as String),
      dueDate: day(r['due_date'] as String),
      expectedHalalas: (r['expected_amount_halalas'] as num?)?.toInt(),
      actualHalalas: (r['actual_amount_halalas'] as num?)?.toInt(),
      status: r['status'] as String,
      transactionId: r['transaction_id'] as String?,
      matchState: (r['match_state'] as String?) ?? 'none',
      graceDays: (rule['grace'] as num?)?.toInt() ?? 0,
      leadDays: (ob['lead_days'] as num?)?.toInt() ?? 2,
    );
  }
}
