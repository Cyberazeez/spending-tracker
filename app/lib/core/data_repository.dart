import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'normalize.dart';

/// Seam over the database for transactions, the review inbox and sender gaps.
const _txnColumns =
    'id, type, direction, amount_halalas, merchant_raw, merchant_norm, category_id, category_source, occurred_at, is_internal, excluded_from_spend';

abstract class DataRepository {
  Future<List<Txn>> recentTransactions({
    TxFilter filter = const TxFilter(),
    int limit = 200,
  });
  Future<List<Category>> categories();

  /// How many other, not manually categorised, transactions share this merchant.
  /// Spending (purchases and refunds with a merchant, not internal) that has no category yet, across all history,
  /// the same set the AI suggestion works on.
  Future<int> uncategorizedSpendCount();

  Future<int> sameMerchantCount(
    String merchantNorm, {
    required String excludingId,
  });

  /// Sets the category of one transaction. When [rememberFor] is given, also saves the owner's rule for that
  /// merchant; with [alsoPast] the other not manually categorised transactions of the merchant change too.
  Future<void> setCategory(
    String txnId,
    String? categoryId, {
    String? rememberFor,
    bool alsoPast = false,
  });
  Future<List<RawMessage>> needsReview();
  Future<void> addManual(ManualTxn t);

  /// Turns an unparsed SMS into a transaction typed in by hand and marks the SMS as handled.
  Future<void> convertRaw(String rawId, ManualTxn t);
  Future<void> dismissRaw(String rawId);
  Future<List<SenderGap>> senderGaps();

  /// Creates the upcoming instances of scheduled obligations and marks late ones overdue (server side).
  Future<void> refreshObligations();
  Future<List<ObligationInstance>> obligationInstances();

  /// The editable details of one obligation, for the edit form.
  Future<ObligationDef> obligation(String id);

  /// Creates ([id] null) or edits one obligation; the server validates it and rebuilds its open instances.
  Future<String> saveObligation(String? id, ObligationDef d);

  /// Stops tracking: history stays, open instances go.
  Future<void> stopObligation(String id);

  /// [status] is `paid`, `skipped` or `pending` (re-open).
  Future<void> setInstanceStatus(String id, String status);

  /// Changes the amount of one instance by hand: the expected amount while it is open, the paid amount once paid.
  Future<void> setInstanceAmount(String id, int halalas, {required bool paid});

  /// The owner accepts / rejects the payment the server suggested for an instance.
  Future<void> confirmMatch(String id);
  Future<void> rejectMatch(String id);

  /// Outgoing, non-internal spend in the current Riyadh month.
  Future<int> monthSpendHalalas();

  /// Outgoing, non-internal spend since midnight Riyadh time today.
  Future<int> todaySpendHalalas();

  /// True when this account is on the paid plan (`settings.ai_allowed`, written only by the server).
  Future<bool> aiAllowed();

  /// The person's own AI switch (`settings.ai_enabled`) AND the paid plan. Off by default.
  Future<bool> aiEnabled();
  Future<void> setAiEnabled(bool on);

  /// The person's consent to have messages from banks the app does not know read by AI (`settings.ai_parse_enabled`).
  Future<bool> aiParseEnabled();
  Future<void> setAiParseEnabled(bool on);

  /// Messages the AI read that still wait for "Looks right" (newest first).
  Future<List<AiRead>> aiReadToCheck();

  /// The reading is right: it stops waiting, and after a few of these the sender needs no more checks.
  Future<void> confirmAiRead(String rawId);

  /// The reading is wrong: the transaction is removed and the message goes back to Needs review to add by hand.
  Future<void> rejectAiRead(String rawId, String txnId);

  /// Asks the server to categorise merchants that have no category yet.
  Future<AiOutcome> suggestCategories();

  /// Asks the server for savings tips on these month totals (numbers and category names only).
  Future<AiOutcome> aiTips(Map<String, dynamic> aggregates, String language);

  /// One chat turn about the month's totals. [turns] is the conversation so far as role/content pairs, ending with
  /// the person's message.
  Future<AiOutcome> aiChat(
    Map<String, dynamic> aggregates,
    List<Map<String, String>> turns,
    String language,
  );

  /// The tips saved for [month] ("YYYY-MM"), newest first, or empty.
  Future<List<String>> savedAiTips(String month, {String? language});

  /// The user's own accounts, cards and wallets (Account > Bank accounts).
  Future<List<OwnAccount>> ownAccounts();
  Future<void> addOwnAccount({
    required String bank,
    required String last4,
    required String kind,
    String? label,
  });
  Future<void> deleteOwnAccount(String id);

  /// The base monthly salary from Settings (0 = not set).
  Future<int> baseSalaryHalalas();

  /// The one overall monthly spending limit, or null when not set.
  Future<int?> monthlyBudgetHalalas();
  Future<void> setMonthlyBudget(int? halalas);

  /// The current Riyadh month and the three before it, for insights.
  Future<List<Txn>> spendingHistory();
  Future<List<Budget>> budgets();
  Future<void> setBudget(String categoryId, int monthlyLimitHalalas);
  Future<void> removeBudget(String categoryId);
}

class SupabaseDataRepository implements DataRepository {
  SupabaseDataRepository(this._db);
  final SupabaseClient _db;

  static String _norm(String s) => normalizeMerchant(s);

  /// Types the server categorises by type, never by merchant: a merchant rule must not touch them.
  static const _typeDriven = [
    'fee',
    'salary',
    'wallet_topup',
    'loan_installment',
    'atm_withdrawal',
  ];

  Map<String, dynamic> _txRow(ManualTxn t, {String? rawId}) => {
    'source': 'manual',
    'direction': t.direction,
    'type': t.direction == 'in' ? 'transfer_in' : 'purchase',
    'amount_halalas': t.amountHalalas,
    'merchant_raw': t.merchant,
    'merchant_norm': t.merchant == null ? null : _norm(t.merchant!),
    'occurred_at': t.occurredAt.toUtc().toIso8601String(),
    'raw_message_id': ?rawId,
  };

  @override
  Future<List<Txn>> recentTransactions({
    TxFilter filter = const TxFilter(),
    int limit = 200,
  }) async {
    var q = _db
        .from('transactions')
        .select(
          'id, type, direction, amount_halalas, merchant_raw, merchant_norm, category_id, category_source, occurred_at, is_internal, excluded_from_spend',
        )
        .isFilter('deleted_at', null);
    final text = normalizeMerchant(filter.query);
    if (text.isNotEmpty) q = q.ilike('merchant_norm', '%$text%');
    if (filter.aiOnly) q = q.eq('category_source', 'ai');
    if (filter.uncategorizedOnly) {
      q = q.isFilter('category_id', null);
    } else if (filter.categoryId != null) {
      q = q.eq('category_id', filter.categoryId!);
    }
    if (filter.hideInternal) q = q.eq('is_internal', false);
    final rows = await q.order('occurred_at', ascending: false).limit(limit);
    return rows.map<Txn>(Txn.fromRow).toList();
  }

  @override
  Future<List<Category>> categories() async {
    final rows = await _db
        .from('categories')
        .select('id, name, name_ar, excluded_from_spend')
        .order('sort_order');
    return rows.map<Category>(Category.fromRow).toList();
  }

  @override
  Future<int> uncategorizedSpendCount() async {
    final rows = await _db
        .from('transactions')
        .select('id')
        .isFilter('deleted_at', null)
        .isFilter('category_id', null)
        .eq('is_internal', false)
        .inFilter('type', ['purchase', 'refund'])
        .not('merchant_norm', 'is', null)
        .limit(5000);
    return rows.length;
  }

  @override
  Future<int> sameMerchantCount(
    String merchantNorm, {
    required String excludingId,
  }) async {
    final rows = await _db
        .from('transactions')
        .select('id')
        .eq('merchant_norm', merchantNorm)
        .neq('id', excludingId)
        .isFilter('deleted_at', null)
        .eq('is_internal', false)
        .not('type', 'in', '(${_typeDriven.join(',')})')
        .or('category_source.is.null,category_source.neq.manual');
    return rows.length;
  }

  @override
  Future<void> setCategory(
    String txnId,
    String? categoryId, {
    String? rememberFor,
    bool alsoPast = false,
  }) async {
    await _db
        .from('transactions')
        .update({
          'category_id': categoryId,
          'category_source': categoryId == null ? null : 'manual',
          'rule_id': null,
        })
        .eq('id', txnId);
    if (rememberFor == null || categoryId == null) return;
    await _db.from('merchant_rules').upsert({
      'pattern': rememberFor,
      'match_type': 'exact',
      'category_id': categoryId,
      'status': 'confirmed',
      'source': 'user',
    }, onConflict: 'user_id,pattern,match_type');
    if (alsoPast) {
      await _db
          .from('transactions')
          .update({
            'category_id': categoryId,
            'category_source': 'rule',
            'rule_id': null,
          })
          .eq('merchant_norm', rememberFor)
          .isFilter('deleted_at', null)
          .eq('is_internal', false)
          .not('type', 'in', '(${_typeDriven.join(',')})')
          .or('category_source.is.null,category_source.neq.manual');
    }
  }

  @override
  Future<List<RawMessage>> needsReview() async {
    final rows = await _db
        .from('raw_messages')
        .select('id, sender, body, received_at')
        .inFilter('parse_status', ['needs_review', 'low_confidence', 'failed'])
        .order('received_at', ascending: false)
        .limit(100);
    return rows.map<RawMessage>(RawMessage.fromRow).toList();
  }

  @override
  Future<void> addManual(ManualTxn t) async {
    await _db.from('transactions').insert(_txRow(t));
  }

  @override
  Future<void> convertRaw(String rawId, ManualTxn t) async {
    final inserted = await _db
        .from('transactions')
        .insert(_txRow(t, rawId: rawId))
        .select('id')
        .single();
    await _db
        .from('raw_messages')
        .update({'parse_status': 'parsed', 'transaction_id': inserted['id']})
        .eq('id', rawId);
  }

  @override
  Future<void> dismissRaw(String rawId) async {
    await _db
        .from('raw_messages')
        .update({
          'parse_status': 'ignored',
          'ignore_reason': 'not_a_transaction',
        })
        .eq('id', rawId);
  }

  @override
  Future<List<SenderGap>> senderGaps() async {
    // Summed in the database (oldest first): reading the newest rows here would silently drop quiet senders.
    final rows = await _db.rpc('my_sender_gaps') as List;
    return rows
        .map<SenderGap>(
          (r) => SenderGap(
            sender: r['sender'] as String,
            lastReceivedAt: DateTime.parse(
              r['last_received_at'] as String,
            ).toUtc(),
          ),
        )
        .toList();
  }

  @override
  Future<void> refreshObligations() async {
    await _db.rpc('refresh_my_obligations');
  }

  @override
  Future<List<ObligationInstance>> obligationInstances() async {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 120));
    final rows = await _db
        .from('obligation_instances')
        .select(
          'id, obligation_id, period_start, due_date, expected_amount_halalas, actual_amount_halalas, status, transaction_id, match_state, obligations(name, kind, due_rule, lead_days, match)',
        )
        .gte('due_date', since.toIso8601String().substring(0, 10))
        .order('due_date')
        .limit(300);
    return rows.map<ObligationInstance>(ObligationInstance.fromRow).toList();
  }

  @override
  Future<ObligationDef> obligation(String id) async {
    final row = await _db
        .from('obligations')
        .select(
          'id, name, kind, amount_type, expected_amount_halalas, frequency, due_rule, lead_days, category_id, match',
        )
        .eq('id', id)
        .single();
    return ObligationDef.fromRow(row);
  }

  @override
  Future<String> saveObligation(String? id, ObligationDef d) async {
    final res = await _db.rpc(
      'save_my_obligation',
      params: {'p_id': id, 'p': d.toRpc()},
    );
    return res as String;
  }

  @override
  Future<void> stopObligation(String id) async {
    await _db.rpc('stop_my_obligation', params: {'p_id': id});
  }

  @override
  Future<void> setInstanceStatus(String id, String status) async {
    final patch = switch (status) {
      'paid' => {
        'status': 'paid',
        'paid_at': DateTime.now().toUtc().toIso8601String(),
        'match_state': 'manual',
        // Marked by hand: count the expected amount as paid unless a payment already set it.
        'actual_amount_halalas':
            (await _db
                    .from('obligation_instances')
                    .select('actual_amount_halalas, expected_amount_halalas')
                    .eq('id', id)
                    .single())
                .let(
                  (r) =>
                      r['actual_amount_halalas'] ??
                      r['expected_amount_halalas'],
                ),
      },
      'skipped' => {'status': 'skipped'},
      _ => {
        'status': 'pending',
        'paid_at': null,
        'match_state': 'none',
        'transaction_id': null,
        'actual_amount_halalas': null,
      },
    };
    await _db.from('obligation_instances').update(patch).eq('id', id);
  }

  @override
  Future<void> setInstanceAmount(
    String id,
    int halalas, {
    required bool paid,
  }) async {
    await _db
        .from('obligation_instances')
        .update({
          paid ? 'actual_amount_halalas' : 'expected_amount_halalas': halalas,
        })
        .eq('id', id);
  }

  @override
  Future<void> confirmMatch(String id) async {
    await _db
        .from('obligation_instances')
        .update({
          'status': 'paid',
          'paid_at': DateTime.now().toUtc().toIso8601String(),
          'match_state': 'manual',
        })
        .eq('id', id);
  }

  @override
  Future<void> rejectMatch(String id) async {
    await _db
        .from('obligation_instances')
        .update({
          'status': 'pending',
          'paid_at': null,
          'transaction_id': null,
          'match_state': 'none',
          'actual_amount_halalas': null,
        })
        .eq('id', id);
  }

  @override
  Future<int> monthSpendHalalas() async {
    final riyadh = DateTime.now().toUtc().add(const Duration(hours: 3));
    final start = DateTime.utc(
      riyadh.year,
      riyadh.month,
    ).subtract(const Duration(hours: 3));
    return _spendSince(start);
  }

  @override
  Future<int> todaySpendHalalas() async {
    final riyadh = DateTime.now().toUtc().add(const Duration(hours: 3));
    final start = DateTime.utc(
      riyadh.year,
      riyadh.month,
      riyadh.day,
    ).subtract(const Duration(hours: 3));
    return _spendSince(start);
  }

  @override
  Future<bool> aiAllowed() async {
    final row = await _db.from('settings').select('ai_allowed').maybeSingle();
    return (row?['ai_allowed'] as bool?) ?? false;
  }

  @override
  Future<bool> aiEnabled() async {
    final row = await _db
        .from('settings')
        .select('ai_enabled, ai_allowed')
        .maybeSingle();
    return ((row?['ai_enabled'] as bool?) ?? false) &&
        ((row?['ai_allowed'] as bool?) ?? false);
  }

  @override
  Future<bool> aiParseEnabled() async {
    final row = await _db
        .from('settings')
        .select('ai_parse_enabled')
        .maybeSingle();
    return (row?['ai_parse_enabled'] as bool?) ?? false;
  }

  @override
  Future<void> setAiParseEnabled(bool on) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    await _db
        .from('settings')
        .update({'ai_parse_enabled': on})
        .eq('user_id', uid);
  }

  @override
  Future<List<AiRead>> aiReadToCheck() async {
    final raws = await _db
        .from('raw_messages')
        .select('id, sender, body, received_at, transaction_id')
        .eq('parse_status', 'ai_parsed')
        .not('transaction_id', 'is', null)
        .order('received_at', ascending: false)
        .limit(50);
    if (raws.isEmpty) return const [];
    final ids = [for (final r in raws) r['transaction_id'] as String];
    final txns = await _db
        .from('transactions')
        .select(_txnColumns)
        .inFilter('id', ids)
        .isFilter('deleted_at', null);
    final byId = {for (final t in txns) t['id'] as String: Txn.fromRow(t)};
    return [
      for (final r in raws)
        if (byId[r['transaction_id']] != null)
          AiRead(raw: RawMessage.fromRow(r), txn: byId[r['transaction_id']]!),
    ];
  }

  @override
  Future<void> confirmAiRead(String rawId) async {
    await _db
        .from('raw_messages')
        .update({'parse_status': 'parsed'})
        .eq('id', rawId);
  }

  @override
  Future<void> rejectAiRead(String rawId, String txnId) async {
    await _db
        .from('transactions')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', txnId);
    await _db
        .from('raw_messages')
        .update({'parse_status': 'needs_review', 'transaction_id': null})
        .eq('id', rawId);
  }

  @override
  Future<void> setAiEnabled(bool on) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    await _db.from('settings').update({'ai_enabled': on}).eq('user_id', uid);
  }

  Future<AiOutcome> _invokeAi(String fn, Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke(fn, body: body);
      final data = res.data;
      if (data is Map) return AiOutcome.fromJson(data.cast<String, dynamic>());
      return const AiOutcome.fail('failed');
    } on FunctionException {
      return const AiOutcome.fail('failed');
    } catch (_) {
      return const AiOutcome.fail('offline');
    }
  }

  @override
  Future<AiOutcome> suggestCategories() => _invokeAi('categorize-batch', {});

  @override
  Future<AiOutcome> aiTips(Map<String, dynamic> aggregates, String language) =>
      _invokeAi('insights-tips', {
        'aggregates': aggregates,
        'language': language,
      });

  @override
  Future<AiOutcome> aiChat(
    Map<String, dynamic> aggregates,
    List<Map<String, String>> turns,
    String language,
  ) => _invokeAi('ai-chat', {
    'aggregates': aggregates,
    'messages': turns,
    'language': language,
  });

  @override
  Future<List<String>> savedAiTips(String month, {String? language}) async {
    final rows = await _db
        .from('insights')
        .select('tips')
        .eq('kind', 'on_demand')
        .eq('period_start', '$month-01')
        .order('created_at', ascending: false)
        .limit(6);
    bool arabic(String s) => RegExp('[\\u0600-\\u06FF]').hasMatch(s);
    for (final row in rows) {
      final tips = [
        for (final t in (row['tips'] as List?) ?? const [])
          if (t is Map && t['text'] is String) t['text'] as String,
      ];
      if (tips.isEmpty) continue;
      // The newest set written in the language the app is showing now.
      if (language == null ||
          tips.every((t) => arabic(t) == (language == 'ar'))) {
        return tips;
      }
    }
    return const [];
  }

  @override
  Future<List<OwnAccount>> ownAccounts() async {
    final rows = await _db
        .from('own_accounts')
        .select('id, bank, last4, kind, label')
        .order('bank')
        .order('last4');
    return rows.map<OwnAccount>(OwnAccount.fromRow).toList();
  }

  @override
  Future<void> addOwnAccount({
    required String bank,
    required String last4,
    required String kind,
    String? label,
  }) async {
    await _db.from('own_accounts').insert({
      'bank': bank,
      'last4': last4,
      'kind': kind,
      'label': (label == null || label.trim().isEmpty) ? null : label.trim(),
    });
  }

  @override
  Future<void> deleteOwnAccount(String id) async {
    await _db.from('own_accounts').delete().eq('id', id);
  }

  @override
  Future<int> baseSalaryHalalas() async {
    final row = await _db
        .from('settings')
        .select('base_salary_halalas')
        .maybeSingle();
    return (row?['base_salary_halalas'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int?> monthlyBudgetHalalas() async {
    final row = await _db
        .from('settings')
        .select('monthly_budget_halalas')
        .maybeSingle();
    return (row?['monthly_budget_halalas'] as num?)?.toInt();
  }

  @override
  Future<void> setMonthlyBudget(int? halalas) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    await _db
        .from('settings')
        .update({'monthly_budget_halalas': halalas})
        .eq('user_id', uid);
  }

  /// Spending since [start], by the same rule as the Insights month total and the widget server:
  /// outgoing money that is not internal, flagged or in an excluded category (Transfers, Income), minus refunds.
  Future<int> _spendSince(DateTime start) async {
    // Summed in the database (an API read returns at most 1000 rows, the rest would be left out).
    final v = await _db.rpc(
      'my_spend_since',
      params: {'p_start': start.toUtc().toIso8601String()},
    );
    return (v as num).toInt();
  }

  @override
  Future<List<Txn>> spendingHistory() async {
    final riyadh = DateTime.now().toUtc().add(const Duration(hours: 3));
    final start = DateTime.utc(
      riyadh.year,
      riyadh.month - 3,
    ).subtract(const Duration(hours: 3));
    // The API returns at most 1000 rows per request, so read the history in pages (newest first).
    const page = 1000;
    final out = <Txn>[];
    for (var from = 0; from < 10 * page; from += page) {
      final rows = await _db
          .from('transactions')
          .select(
            'id, type, direction, amount_halalas, merchant_raw, merchant_norm, category_id, category_source, occurred_at, is_internal, excluded_from_spend',
          )
          .isFilter('deleted_at', null)
          .gte('occurred_at', start.toIso8601String())
          .order('occurred_at', ascending: false)
          // A transfer and its fee share a time; without a tiebreaker the pages can repeat or skip rows.
          .order('id', ascending: false)
          .range(from, from + page - 1);
      out.addAll(rows.map<Txn>(Txn.fromRow));
      if (rows.length < page) break;
    }
    return out;
  }

  @override
  Future<List<Budget>> budgets() async {
    final rows = await _db
        .from('budgets')
        .select('id, category_id, monthly_limit_halalas');
    return rows.map<Budget>(Budget.fromRow).toList();
  }

  @override
  Future<void> setBudget(String categoryId, int monthlyLimitHalalas) async {
    await _db.from('budgets').upsert({
      'category_id': categoryId,
      'monthly_limit_halalas': monthlyLimitHalalas,
    }, onConflict: 'user_id,category_id');
  }

  @override
  Future<void> removeBudget(String categoryId) async {
    await _db.from('budgets').delete().eq('category_id', categoryId);
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
