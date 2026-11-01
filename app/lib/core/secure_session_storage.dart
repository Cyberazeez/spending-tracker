import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where the session string is kept. A seam so the storage logic is testable without a device keychain.
abstract class SecureKeyValue {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The iOS keychain: the session is encrypted by the OS, never leaves this device (no iCloud sync) and is only
/// readable after the first unlock since boot.
class KeychainKeyValue implements SecureKeyValue {
  KeychainKeyValue([FlutterSecureStorage? storage])
    : _s =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

/// Keeps the Supabase session in the keychain instead of plain preferences.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this._kv);
  final SecureKeyValue _kv;
  static const key = 'spending_tracker.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _read()) != null;

  @override
  Future<String?> accessToken() => _read();

  @override
  Future<void> persistSession(String persistSessionString) async {
    // A keychain write failure must not break sign-in; the session just won't survive a restart.
    try {
      await _kv.write(key, persistSessionString);
    } catch (_) {}
  }

  @override
  Future<void> removePersistedSession() => _kv.delete(key);

  /// A keychain that cannot be read (for example locked) must look like "signed out", not crash the app.
  Future<String?> _read() async {
    try {
      final v = await _kv.read(key);
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }
}
