import 'package:supabase_flutter/supabase_flutter.dart';

enum SignInFailure { invalidCredentials, network }

enum SignUpFailure { emailTaken, weakPassword, invalidEmail, disabled, network }

class SignUpException implements Exception {
  const SignUpException(this.failure);
  final SignUpFailure failure;
}

/// What happened after a successful sign-up request: the account is signed in at once, or the person must first
/// follow the confirmation link emailed to them (only when the project asks for email confirmation).
enum SignUpResult { signedIn, confirmEmail }

enum PasswordFailure { wrongCurrent, tooShort, network }

class PasswordException implements Exception {
  const PasswordException(this.failure);
  final PasswordFailure failure;
}

class SignInException implements Exception {
  const SignInException(this.failure);
  final SignInFailure failure;
}

/// Thin seam over Supabase auth so screens and tests do not touch the SDK directly.
abstract class AuthRepository {
  bool get hasSession;
  String? get userId;
  Stream<bool> get signedIn;
  Future<void> signIn(String email, String password);

  /// Creates an account (family testing: open sign-up). Throws [SignUpException].
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> signOut();

  String? get email;

  /// The name the user typed in Account > Profile (kept in the account's own profile data), or null.
  String? get displayName;
  Future<void> updateName(String name);

  /// Starts an email change: the new address gets a confirmation link and the old one stays until it is used.
  Future<void> changeEmail(String email);

  /// Checks [current] first, then sets [next]. Throws [PasswordException].
  Future<void> changePassword({required String current, required String next});
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  String? get userId => _client.auth.currentUser?.id;

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
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      // With "confirm email" on, no session comes back and the person has to use the emailed link first.
      return res.session == null
          ? SignUpResult.confirmEmail
          : SignUpResult.signedIn;
    } on AuthWeakPasswordException {
      throw const SignUpException(SignUpFailure.weakPassword);
    } on AuthApiException catch (e) {
      switch (e.code) {
        case 'user_already_exists':
        case 'email_exists':
          throw const SignUpException(SignUpFailure.emailTaken);
        case 'weak_password':
          throw const SignUpException(SignUpFailure.weakPassword);
        case 'email_address_invalid':
        case 'validation_failed':
          throw const SignUpException(SignUpFailure.invalidEmail);
        case 'signup_disabled':
          throw const SignUpException(SignUpFailure.disabled);
      }
      throw const SignUpException(SignUpFailure.network);
    } catch (_) {
      throw const SignUpException(SignUpFailure.network);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  String? get displayName {
    final n = _client.auth.currentUser?.userMetadata?['name'];
    return n is String && n.trim().isNotEmpty ? n.trim() : null;
  }

  @override
  Future<void> updateName(String name) async {
    await _client.auth.updateUser(UserAttributes(data: {'name': name.trim()}));
  }

  @override
  Future<void> changeEmail(String email) async {
    await _client.auth.updateUser(UserAttributes(email: email.trim()));
  }

  @override
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    final me = email;
    if (me == null) throw const PasswordException(PasswordFailure.network);
    try {
      await _client.auth.signInWithPassword(email: me, password: current);
    } on AuthApiException catch (e) {
      // Only a rejected password is "wrong"; rate limits and server errors are a network problem.
      if (e.code == 'invalid_credentials') {
        throw const PasswordException(PasswordFailure.wrongCurrent);
      }
      throw const PasswordException(PasswordFailure.network);
    } catch (_) {
      throw const PasswordException(PasswordFailure.network);
    }
    try {
      await _client.auth.updateUser(UserAttributes(password: next));
    } on AuthWeakPasswordException {
      throw const PasswordException(PasswordFailure.tooShort);
    } on AuthApiException catch (e) {
      if (e.code == 'weak_password') {
        throw const PasswordException(PasswordFailure.tooShort);
      }
      throw const PasswordException(PasswordFailure.network);
    } catch (_) {
      throw const PasswordException(PasswordFailure.network);
    }
  }
}
