import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'normalize.dart';

/// Seam over the database for transactions, the review inbox and sender gaps.
abstract class DataRepository {
  Future<List<Txn>> recentTransactions({
    TxFilter filter = const TxFilter(),
    int limit = 200,
  });
  Future<List<Category>> categories();

  /// How many other, not manually categorised, transactions share this merchant.
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
          'id, type, direction, amount_halalas, merchant_raw, merchant_norm, category_id, occurred_at, is_internal',
        )
        .isFilter('deleted_at', null);
    final text = normalizeMerchant(filter.query);
    if (text.isNotEmpty) q = q.ilike('merchant_norm', '%$text%');
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
        .select('id, name, name_ar')
        .order('sort_order');
    return rows.map<Category>(Category.fromRow).toList();
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
    final rows = await _db
        .from('raw_messages')
        .select('sender, received_at')
        .order('received_at', ascending: false)
        .limit(500);
    final latest = <String, DateTime>{};
    for (final r in rows) {
      latest.putIfAbsent(
        r['sender'] as String,
        () => DateTime.parse(r['received_at'] as String).toUtc(),
      );
    }
    return latest.entries
        .map((e) => SenderGap(sender: e.key, lastReceivedAt: e.value))
        .toList()
      ..sort((a, b) => a.lastReceivedAt!.compareTo(b.lastReceivedAt!));
  }
}
