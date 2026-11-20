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
    this.bank,
    this.accountLast4,
    this.cardLast4,
    this.note,
    this.source,
    this.rawMessageId,
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

  /// The bank code and the last four digits of the account or card it was paid with, when known.
  final String? bank;
  final String? accountLast4;

  /// The card's last four digits when the bank SMS names the card (it is kept apart from the account's).
  final String? cardLast4;

  /// The card or account to show: the card when known, else the account.
  String? get paidWithLast4 => cardLast4 ?? accountLast4;

  /// A copy with another category (after it was changed on the transaction page).
  Txn withCategory(String? id) => Txn(
    id: this.id,
    type: type,
    direction: direction,
    amountHalalas: amountHalalas,
    occurredAt: occurredAt,
    merchant: merchant,
    merchantNorm: merchantNorm,
    categoryId: id,
    isInternal: isInternal,
    excludedFromSpend: excludedFromSpend,
    categorySource: id == null ? null : 'manual',
    bank: bank,
    accountLast4: accountLast4,
    cardLast4: cardLast4,
    note: note,
    source: source,
    rawMessageId: rawMessageId,
  );

  /// The owner's own note.
  final String? note;

  /// Where it came from: `sms`, `manual`, `csv` or `ai`.
  final String? source;

  /// The bank SMS it was read from, when there is one.
  final String? rawMessageId;

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
    bank: r['bank'] as String?,
    accountLast4: r['account_last4'] as String?,
    cardLast4: r['card_last4'] as String?,
    note: r['note'] as String?,
    source: r['source'] as String?,
    rawMessageId: r['raw_message_id'] as String?,
  );
}

class RawMessage {
  const RawMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.parseStatus = 'needs_review',
  });

  final String id;
  final String sender;
  final String body;
  final DateTime receivedAt;

  /// Why it waits for review: `needs_review` (no reader knows this format yet), `low_confidence` (read, but not
  /// sure) or `failed` (a reader broke on it).
  final String parseStatus;

  factory RawMessage.fromRow(Map<String, dynamic> r) => RawMessage(
    id: r['id'] as String,
    sender: r['sender'] as String,
    body: r['body'] as String,
    receivedAt: DateTime.parse(r['received_at'] as String).toUtc(),
    parseStatus: (r['parse_status'] as String?) ?? 'needs_review',
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
    this.categoryId,
    this.bank,
    this.accountLast4,
    this.cardLast4,
    this.note,
  });

  final String direction;
  final int amountHalalas;
  final DateTime occurredAt;
  final String? merchant;

  /// Chosen on the Add a transaction screen; null leaves it to the merchant rules.
  final String? categoryId;

  /// "Paid with": one of the owner's accounts; a card's digits go in [cardLast4], an account's in [accountLast4]
  /// (as the bank SMS reader stores them).
  final String? bank;
  final String? accountLast4;
  final String? cardLast4;
  final String? note;
}

/// A saved "always file this place under that category" rule.
class MerchantRule {
  const MerchantRule({
    required this.id,
    required this.pattern,
    required this.categoryId,
  });
  final String id;
  final String pattern;
  final String categoryId;
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
/// Which months the Activity list shows.
enum TxPeriod { thisMonth, lastMonth, custom, all }

class TxFilter {
  const TxFilter({
    this.query = '',
    this.categoryId,
    this.uncategorizedOnly = false,
    this.hideInternal = false,
    this.aiOnly = false,
    this.period = TxPeriod.thisMonth,
    this.from,
    this.to,
    this.categoryIds,
    this.accountLast4,
  });
  final String query;
  final String? categoryId;
  final bool uncategorizedOnly;
  final bool hideInternal;

  /// Only rows whose category was suggested by the AI.
  final bool aiOnly;

  /// This month (the default), last month, a custom range ([from] to [to], both days included) or everything.
  final TxPeriod period;
  final DateTime? from;
  final DateTime? to;

  /// A category group chosen in the filter sheet: the ids of its categories (null = every category).
  final List<String>? categoryIds;

  /// Only one account or card (its last four digits).
  final String? accountLast4;

  /// The date range of [period] as UTC instants [start, end), in Riyadh days (UTC+3). Null for everything.
  (DateTime, DateTime)? range(DateTime now) {
    final riyadh = now.toUtc().add(const Duration(hours: 3));
    DateTime utc(int y, int m, int d) =>
        DateTime.utc(y, m, d).subtract(const Duration(hours: 3));
    switch (period) {
      case TxPeriod.thisMonth:
        return (
          utc(riyadh.year, riyadh.month, 1),
          utc(riyadh.year, riyadh.month + 1, 1),
        );
      case TxPeriod.lastMonth:
        return (
          utc(riyadh.year, riyadh.month - 1, 1),
          utc(riyadh.year, riyadh.month, 1),
        );
      case TxPeriod.custom:
        final f = from, t = to;
        if (f == null || t == null) return null;
        return (utc(f.year, f.month, f.day), utc(t.year, t.month, t.day + 1));
      case TxPeriod.all:
        return null;
    }
  }

  /// Anything narrowed beyond the default (this month, every category and account).
  /// How many filters the sheet has on (the search box shows its own text, so it is not counted).
  int get count => [
    categoryId != null || categoryIds != null,
    uncategorizedOnly,
    hideInternal,
    aiOnly,
    period != TxPeriod.thisMonth,
    accountLast4 != null,
  ].where((on) => on).length;

  bool get isActive =>
      query.isNotEmpty ||
      categoryId != null ||
      uncategorizedOnly ||
      hideInternal ||
      aiOnly ||
      period != TxPeriod.thisMonth ||
      categoryIds != null ||
      accountLast4 != null;

  TxFilter copyWith({
    String? query,
    Object? categoryId = _keep,
    bool? uncategorizedOnly,
    bool? hideInternal,
    bool? aiOnly,
    TxPeriod? period,
    Object? from = _keep,
    Object? to = _keep,
    Object? categoryIds = _keep,
    Object? accountLast4 = _keep,
  }) => TxFilter(
    query: query ?? this.query,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as String?,
    uncategorizedOnly: uncategorizedOnly ?? this.uncategorizedOnly,
    hideInternal: hideInternal ?? this.hideInternal,
    aiOnly: aiOnly ?? this.aiOnly,
    period: period ?? this.period,
    from: identical(from, _keep) ? this.from : from as DateTime?,
    to: identical(to, _keep) ? this.to : to as DateTime?,
    categoryIds: identical(categoryIds, _keep)
        ? this.categoryIds
        : categoryIds as List<String>?,
    accountLast4: identical(accountLast4, _keep)
        ? this.accountLast4
        : accountLast4 as String?,
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
    this.active = true,
    this.line,
    this.biller,
    this.nextMonth,
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

  /// False once the bill was stopped. Not sent: saving always (re)activates on the server.
  final bool active;

  /// A bill made from a pasted bill message: the line or account's last 4 and who sends the notices (`stc` or
  /// `se`). Sent only when set; the bill form never sends it, so a later save keeps the bill's line.
  final String? line;
  final String? biller;

  /// Due the month after it is issued. Sent only when set.
  final bool? nextMonth;

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
      active: (r['active'] as bool?) ?? true,
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
    if (line != null) 'line': line,
    if (line != null) 'biller': biller ?? 'stc',
    'next_month': ?nextMonth,
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
  final String kind; // bill | fixed | loan (card_statement rows are hidden)
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
  final String bank; // a code from bankList (banks.dart)
  final String last4;
  final String kind; // account | debit_card | credit_card | wallet
  final String? label;

  static const kinds = ['account', 'debit_card', 'credit_card', 'wallet'];

  factory OwnAccount.fromRow(Map<String, dynamic> r) => OwnAccount(
    id: r['id'] as String,
    bank: r['bank'] as String,
    last4: r['last4'] as String,
    kind: r['kind'] as String,
    label: r['label'] as String?,
  );
}

/// A stored purchase that looks the same as a pasted one (same amount and card, within 10 minutes).
class PasteDuplicate {
  const PasteDuplicate({
    required this.id,
    required this.amountHalalas,
    required this.occurredAt,
    this.merchant,
    this.categoryId,
  });

  final String id;
  final String? merchant;
  final int amountHalalas;
  final DateTime occurredAt;
  final String? categoryId;

  factory PasteDuplicate.fromJson(Map<String, dynamic> j) => PasteDuplicate(
    id: j['id'] as String,
    merchant: j['merchant'] as String?,
    amountHalalas: (j['amountHalalas'] as num).toInt(),
    occurredAt: DateTime.parse(j['occurredAt'] as String),
    categoryId: j['categoryId'] as String?,
  );
}

/// What a pasted message says, before anything is saved (the `paste-sms` function's preview).
class PastePreview {
  const PastePreview({
    required this.kind,
    this.reader,
    this.detected = false,
    this.type,
    this.direction,
    this.bank,
    this.amountHalalas,
    this.merchant,
    this.cardLast4,
    this.accountLast4,
    this.occurredAt,
    this.isInternal = false,
    this.categoryId,
    this.duplicates = const [],
    this.aiAvailable = false,
    this.biller,
    this.lineLast4,
    this.issuedAt,
    this.billId,
    this.billName,
    this.billExpectedHalalas,
    this.billPeriodStart,
    this.billDueDate,
    this.receivedAt,
    this.ambiguous = false,
  });

  /// The time the server read it with: sent back on commit, so the same message always has the same fingerprint.
  final DateTime? receivedAt;

  /// Not read because several banks' readers understood it: the person picks the bank.
  final bool ambiguous;

  /// transaction | bill | statement | ignored | unparsed
  final String kind;

  /// The reader that understood it (a bank code, `stc900` or `se`), or null when none or several did.
  final String? reader;

  /// The reader was found from the text (not picked by the person).
  final bool detected;

  // A purchase or other transaction.
  final String? type;
  final String? direction;
  final String? bank;
  final int? amountHalalas;
  final String? merchant;
  final String? cardLast4;
  final String? accountLast4;
  final DateTime? occurredAt;
  final bool isInternal;
  final String? categoryId;
  final List<PasteDuplicate> duplicates;

  /// Not read: Read with AI can be offered (the AI switch is on).
  final bool aiAvailable;

  // A bill notice.
  final String? biller;
  final String? lineLast4;
  final DateTime? issuedAt;
  final String? billId;
  final String? billName;
  final int? billExpectedHalalas;
  final DateTime? billPeriodStart;
  final DateTime? billDueDate;

  factory PastePreview.fromJson(Map<String, dynamic> j) {
    final r = (j['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final bill = (r['bill'] as Map?)?.cast<String, dynamic>();
    int? n(Object? v) => (v as num?)?.toInt();
    DateTime? d(Object? v) => v is String ? DateTime.parse(v) : null;
    return PastePreview(
      kind: (r['kind'] as String?) ?? 'unparsed',
      reader: j['reader'] as String?,
      detected: j['detected'] == true,
      type: r['type'] as String?,
      direction: r['direction'] as String?,
      bank: r['bank'] as String?,
      // a bill notice's total comes as totalHalalas
      amountHalalas: n(r['amountHalalas'] ?? r['totalHalalas']),
      merchant: r['merchant'] as String?,
      cardLast4: r['cardLast4'] as String?,
      accountLast4: r['accountLast4'] as String?,
      occurredAt: d(r['occurredAt']),
      isInternal: r['isInternal'] == true,
      categoryId: r['categoryId'] as String?,
      duplicates: [
        for (final x in (j['duplicates'] as List?) ?? const [])
          PasteDuplicate.fromJson((x as Map).cast<String, dynamic>()),
      ],
      aiAvailable: r['aiAvailable'] == true,
      biller: r['biller'] as String?,
      lineLast4: r['lineLast4'] as String?,
      issuedAt: d(r['issuedAt']),
      billId: bill?['id'] as String?,
      billName: bill?['name'] as String?,
      billExpectedHalalas: n(bill?['expectedHalalas']),
      billPeriodStart: d(bill?['periodStart']),
      billDueDate: d(bill?['dueDate']),
      receivedAt: d(j['receivedAt']),
      ambiguous: r['ambiguous'] == true,
    );
  }
}

/// What saving a pasted message did: parsed (saved), review (an AI reading waits for a check), notice (a bill was
/// updated), ignored, unparsed (kept in Needs review). [duplicate]: the very same message was already stored.
class PasteResult {
  const PasteResult({
    required this.outcome,
    this.duplicate = false,
    this.same = const [],
  });

  /// parsed | review | notice | ignored | unparsed, or `same`: not saved, a stored purchase looks the same ([same]).
  final String outcome;
  final bool duplicate;
  final List<PasteDuplicate> same;

  factory PasteResult.fromJson(Map<String, dynamic> j) => PasteResult(
    outcome: (j['outcome'] as String?) ?? 'unparsed',
    duplicate: j['duplicate'] == true,
  );
}
