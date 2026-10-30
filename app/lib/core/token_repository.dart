import 'package:supabase_flutter/supabase_flutter.dart';

class IngestTokenInfo {
  const IngestTokenInfo({
    required this.label,
    required this.createdAt,
    this.lastUsedAt,
  });
  final String label;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
}

/// Ingest token metadata (never the hash) and rotation through the `rotate-token` function.
abstract class TokenRepository {
  Future<IngestTokenInfo?> activeToken();

  /// Creates a new token, revokes the old ones, returns the plaintext once.
  Future<String> rotate({String label = 'iPhone'});
}

class SupabaseTokenRepository implements TokenRepository {
  SupabaseTokenRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<IngestTokenInfo?> activeToken() async {
    final rows = await _client
        .from('ingest_tokens')
        .select('label, created_at, last_used_at')
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return IngestTokenInfo(
      label: r['label'] as String,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      lastUsedAt: r['last_used_at'] == null
          ? null
          : DateTime.parse(r['last_used_at'] as String).toLocal(),
    );
  }

  @override
  Future<String> rotate({String label = 'iPhone'}) async {
    final res = await _client.functions.invoke(
      'rotate-token',
      body: {'label': label},
    );
    final data = res.data;
    if (data is Map && data['token'] is String) return data['token'] as String;
    throw StateError('rotate-token returned no token');
  }
}
