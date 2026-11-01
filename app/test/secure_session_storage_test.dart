import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/secure_session_storage.dart';

class _Mem implements SecureKeyValue {
  final map = <String, String>{};
  bool throwOnRead = false;
  @override
  Future<String?> read(String key) async {
    if (throwOnRead) throw StateError('keychain locked');
    return map[key];
  }

  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

void main() {
  test('persists, reads and removes the session', () async {
    final kv = _Mem();
    final s = SecureSessionStorage(kv);
    expect(await s.hasAccessToken(), isFalse);
    await s.persistSession('{"a":1}');
    expect(await s.hasAccessToken(), isTrue);
    expect(await s.accessToken(), '{"a":1}');
    expect(kv.map.keys.single, SecureSessionStorage.key);
    await s.removePersistedSession();
    expect(await s.hasAccessToken(), isFalse);
  });

  test('an unreadable keychain looks signed out instead of crashing', () async {
    final kv = _Mem()..throwOnRead = true;
    final s = SecureSessionStorage(kv);
    expect(await s.hasAccessToken(), isFalse);
    expect(await s.accessToken(), isNull);
  });

  test('an empty stored value is treated as no session', () async {
    final kv = _Mem()..map[SecureSessionStorage.key] = '';
    expect(await SecureSessionStorage(kv).hasAccessToken(), isFalse);
  });
}
