import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Seam over the database for transactions, the review inbox and sender gaps.
abstract class DataRepository {
  Future<List<Txn>> recentTransactions({int limit = 200});
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

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

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
  Future<List<Txn>> recentTransactions({int limit = 200}) async {
    final rows = await _db
        .from('transactions')
        .select(
          'id, type, direction, amount_halalas, merchant_raw, occurred_at, is_internal',
        )
        .isFilter('deleted_at', null)
        .order('occurred_at', ascending: false)
        .limit(limit);
    return rows.map<Txn>(Txn.fromRow).toList();
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
