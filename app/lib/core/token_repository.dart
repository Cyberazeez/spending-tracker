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
  Future<String> rotate({String label = 'iPhone', String kind = 'shortcut'});

  /// Revokes every active token of [kind] (used on sign-out for the app's own token).
  Future<void> revoke({String kind = 'app'});

  /// Whether the server still has an active token of [kind]. False after the server revoked it (password change on
  /// another device, 90 days unused): the phone's copy is dead and must be replaced.
  Future<bool> hasActive({required String kind});
}

class SupabaseTokenRepository implements TokenRepository {
  SupabaseTokenRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<IngestTokenInfo?> activeToken() async {
    final rows = await _client
        .from('ingest_tokens')
        .select('label, created_at, last_used_at')
        .eq(
          'kind',
          'shortcut',
        ) // the app's own token (kind 'app') is not shown here
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
  Future<String> rotate({
    String label = 'iPhone',
    String kind = 'shortcut',
  }) async {
    final res = await _client.functions.invoke(
      'rotate-token',
      body: {'label': label, 'kind': kind},
    );
    final data = res.data;
    if (data is Map && data['token'] is String) return data['token'] as String;
    throw StateError('rotate-token returned no token');
  }

  @override
  Future<bool> hasActive({required String kind}) async {
    final rows = await _client
        .from('ingest_tokens')
        .select('id')
        .eq('kind', kind)
        .isFilter('revoked_at', null)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> revoke({String kind = 'app'}) async {
    await _client.functions.invoke(
      'rotate-token',
      body: {'kind': kind, 'action': 'revoke'},
    );
  }
}
