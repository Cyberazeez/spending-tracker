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
    this.excludedFromSpend = false,
    this.categorySource,
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
  final bool excludedFromSpend;

  /// How the category was set: `rule`, `manual`, `ai`, ... (null when unknown). `ai` rows are shown with a tag.
  final String? categorySource;

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
    excludedFromSpend: (r['excluded_from_spend'] as bool?) ?? false,
    categorySource: r['category_source'] as String?,
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

/// A message the AI read (a bank the app has no parser for): the person checks what it made of it.
class AiRead {
  const AiRead({required this.raw, required this.txn});
  final RawMessage raw;
  final Txn txn;
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
  const Category({
    required this.id,
    required this.name,
    this.nameAr,
    this.excludedFromSpend = false,
  });
  final String id;
  final String name;
  final String? nameAr;
  final bool excludedFromSpend;

  String label({required bool arabic}) =>
      arabic && (nameAr?.isNotEmpty ?? false) ? nameAr! : name;

  factory Category.fromRow(Map<String, dynamic> r) => Category(
    id: r['id'] as String,
    name: r['name'] as String,
    nameAr: r['name_ar'] as String?,
    excludedFromSpend: (r['excluded_from_spend'] as bool?) ?? false,
  );
}

/// What the Transactions list is currently showing.
class TxFilter {
  const TxFilter({
    this.query = '',
    this.categoryId,
    this.uncategorizedOnly = false,
    this.hideInternal = false,
    this.aiOnly = false,
  });
  final String query;
  final String? categoryId;
  final bool uncategorizedOnly;
  final bool hideInternal;

  /// Only rows whose category was suggested by the AI.
  final bool aiOnly;

  bool get isActive =>
      query.isNotEmpty ||
      categoryId != null ||
      uncategorizedOnly ||
      hideInternal ||
      aiOnly;

  TxFilter copyWith({
    String? query,
    Object? categoryId = _keep,
    bool? uncategorizedOnly,
    bool? hideInternal,
    bool? aiOnly,
  }) => TxFilter(
    query: query ?? this.query,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as String?,
    uncategorizedOnly: uncategorizedOnly ?? this.uncategorizedOnly,
    hideInternal: hideInternal ?? this.hideInternal,
    aiOnly: aiOnly ?? this.aiOnly,
  );

  static const _keep = Object();
}

/// The editable details of one obligation (the form in Bills). Seeded card statements are never edited.
class ObligationDef {
  const ObligationDef({
    required this.name,
    this.id,
    this.kind = 'fixed',
    this.amountType = 'fixed',
    this.amountHalalas,
    this.frequency = 'monthly',
    this.day = 1,
    this.startMonth,
    this.graceDays = 3,
    this.leadDays = 2,
    this.categoryId,
    this.merchantWords = const [],
    this.tolerancePct = 10,
    this.autoMerchant = false,
  });

  final String? id;
  final String name;
  final String kind; // bill | fixed | loan
  final String amountType; // fixed | estimated
  final int? amountHalalas;
  final String frequency; // monthly | quarterly | annual
  final int day; // 1..31
  final int? startMonth; // 1..12, quarterly and annual only
  final int graceDays;
  final int leadDays;
  final String? categoryId;
  final List<String> merchantWords;
  final int tolerancePct;
  final bool autoMerchant;

  factory ObligationDef.fromRow(Map<String, dynamic> r) {
    final rule = (r['due_rule'] as Map?)?.cast<String, dynamic>() ?? const {};
    final match = (r['match'] as Map?)?.cast<String, dynamic>() ?? const {};
    int? n(Object? v) => (v as num?)?.toInt();
    return ObligationDef(
      id: r['id'] as String?,
      name: (r['name'] as String?) ?? '',
      kind: (r['kind'] as String?) ?? 'fixed',
      amountType: (r['amount_type'] as String?) ?? 'fixed',
      amountHalalas: n(r['expected_amount_halalas']),
      frequency: (r['frequency'] as String?) ?? 'monthly',
      day: n(rule['day']) ?? n(rule['fallback_day']) ?? 28,
      startMonth: n(rule['start_month']),
      graceDays: n(rule['grace']) ?? 0,
      leadDays: n(r['lead_days']) ?? 2,
      categoryId: r['category_id'] as String?,
      merchantWords: [
        for (final w in (match['merchant'] as List?) ?? const []) w.toString(),
      ],
      tolerancePct: n(match['tolerance_pct']) ?? 10,
      autoMerchant: (match['auto_merchant'] as bool?) ?? false,
    );
  }

  /// The payload of the `save_my_obligation` function, which validates it again on the server.
  Map<String, dynamic> toRpc() => {
    'name': name,
    'kind': kind,
    'amount_type': amountType,
    'amount_halalas': amountHalalas,
    'frequency': frequency,
    'day': day,
    'start_month': frequency == 'monthly' ? null : startMonth,
    'grace': graceDays,
    'lead_days': leadDays,
    'category_id': categoryId,
    'merchant': merchantWords,
    'tolerance_pct': tolerancePct,
    'auto_merchant': autoMerchant,
  };
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
    this.issueDay,
    this.plan,
    this.usualMinHalalas,
    this.usualMaxHalalas,
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

  /// The day of the month the bill is usually issued (not due). Decides its billing cycle, see `cycleOf`.
  final int? issueDay;

  /// An instalment plan whose payments are already inside this statement's total (card statements only).
  final InstalmentPlan? plan;

  /// The usual range of a bill whose amount varies (electricity), shown instead of one exact figure.
  final int? usualMinHalalas;
  final int? usualMaxHalalas;

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
      issueDay: (rule['issue_day'] as num?)?.toInt(),
      plan: InstalmentPlan.fromJson(
        ((ob['match'] as Map?)?['plan'] as Map?)?.cast<String, dynamic>(),
      ),
      usualMinHalalas:
          (((ob['match'] as Map?)?['range'] as Map?)?['min_halalas'] as num?)
              ?.toInt(),
      usualMaxHalalas:
          (((ob['match'] as Map?)?['range'] as Map?)?['max_halalas'] as num?)
              ?.toInt(),
    );
  }
}

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.limitHalalas,
  });
  final String id;
  final String categoryId;
  final int limitHalalas;

  factory Budget.fromRow(Map<String, dynamic> r) => Budget(
    id: r['id'] as String,
    categoryId: r['category_id'] as String,
    limitHalalas: (r['monthly_limit_halalas'] as num).toInt(),
  );
}

/// A card payment plan: [months] equal instalments from the statement of [first] (YYYY-MM).
class InstalmentPlan {
  const InstalmentPlan({
    required this.name,
    required this.instalmentHalalas,
    required this.months,
    required this.firstYear,
    required this.firstMonth,
  });
  final String name;
  final int instalmentHalalas;
  final int months;
  final int firstYear;
  final int firstMonth;

  static InstalmentPlan? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final first = RegExp(r'^(\d{4})-(\d{2})$').firstMatch('${j['first']}');
    final amount = (j['instalment_halalas'] as num?)?.toInt();
    final months = (j['months'] as num?)?.toInt();
    if (first == null || amount == null || months == null || months < 1) {
      return null;
    }
    return InstalmentPlan(
      name: '${j['name'] ?? ''}',
      instalmentHalalas: amount,
      months: months,
      firstYear: int.parse(first.group(1)!),
      firstMonth: int.parse(first.group(2)!),
    );
  }

  /// Which instalment (1-based) falls in the statement of this month, or null when none does.
  int? numberFor(DateTime statementMonth) {
    final n =
        (statementMonth.year * 12 + statementMonth.month) -
        (firstYear * 12 + firstMonth) +
        1;
    return n >= 1 && n <= months ? n : null;
  }
}

/// What an AI call (suggest categories, savings tips) came back with. [reason] is one of the server's codes
/// (`disabled`, `no_key`, `cap_reached`, `failed`) or `offline` when the call itself did not get through.
class AiOutcome {
  const AiOutcome.ok({this.updated = 0, this.tips = const [], this.reply = ''})
    : ok = true,
      reason = null;
  const AiOutcome.fail(this.reason)
    : ok = false,
      updated = 0,
      tips = const [],
      reply = '';

  final bool ok;
  final String? reason;

  /// Transactions that got a category (suggest categories).
  final int updated;

  /// Short savings tips (insights).
  final List<String> tips;

  /// The assistant's answer (chat).
  final String reply;

  factory AiOutcome.fromJson(Map<String, dynamic> j) {
    if (j['ok'] != true) {
      return AiOutcome.fail((j['reason'] as String?) ?? 'failed');
    }
    return AiOutcome.ok(
      updated: (j['updated'] as num?)?.toInt() ?? 0,
      reply: (j['reply'] as String?) ?? '',
      tips: [
        for (final t in (j['tips'] as List?) ?? const [])
          if (t is Map && t['text'] is String) t['text'] as String,
      ],
    );
  }
}

/// One of the user's own bank accounts, cards or wallets. Transfers between these are internal, not spending.
class OwnAccount {
  const OwnAccount({
    required this.id,
    required this.bank,
    required this.last4,
    required this.kind,
    this.label,
  });

  final String id;
  final String bank; // alrajhi | snb | alinma | barq | d360 | stc
  final String last4;
  final String kind; // account | debit_card | credit_card | wallet
  final String? label;

  static const banks = ['alrajhi', 'snb', 'alinma', 'barq', 'd360', 'stc'];
  static const kinds = ['account', 'debit_card', 'credit_card', 'wallet'];

  factory OwnAccount.fromRow(Map<String, dynamic> r) => OwnAccount(
    id: r['id'] as String,
    bank: r['bank'] as String,
    last4: r['last4'] as String,
    kind: r['kind'] as String,
    label: r['label'] as String?,
  );
}
