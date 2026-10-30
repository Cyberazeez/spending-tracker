import 'package:supabase_flutter/supabase_flutter.dart';

enum SignInFailure { invalidCredentials, network }

class SignInException implements Exception {
  const SignInException(this.failure);
  final SignInFailure failure;
}

/// Thin seam over Supabase auth so screens and tests do not touch the SDK directly.
abstract class AuthRepository {
  bool get hasSession;
  Stream<bool> get signedIn;
  Future<void> signIn(String email, String password);
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  Stream<bool> get signedIn =>
      _client.auth.onAuthStateChange.map((e) => e.session != null);

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthApiException catch (e) {
      if (e.statusCode == '400' || e.code == 'invalid_credentials') {
        throw const SignInException(SignInFailure.invalidCredentials);
      }
      throw const SignInException(SignInFailure.network);
    } on AuthException {
      throw const SignInException(SignInFailure.invalidCredentials);
    } catch (_) {
      throw const SignInException(SignInFailure.network);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
