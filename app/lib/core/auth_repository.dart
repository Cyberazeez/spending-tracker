import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

enum SignInFailure { invalidCredentials, network }

enum SignUpFailure {
  emailTaken,
  weakPassword,
  invalidEmail,
  disabled,
  tryLater,
  network,
}

class SignUpException implements Exception {
  const SignUpException(this.failure);
  final SignUpFailure failure;
}

/// What happened after a successful sign-up request: the account is signed in at once, or the person must first
/// follow the confirmation link emailed to them (only when the project asks for email confirmation).
enum SignUpResult { signedIn, confirmEmail }

enum DeleteFailure { wrongPassword, tooMany, network }

class DeleteAccountException implements Exception {
  const DeleteAccountException(this.failure);
  final DeleteFailure failure;
}

enum PasswordFailure { wrongCurrent, tooShort, network }

enum ResetFailure { tryLater, network }

class ResetException implements Exception {
  const ResetException(this.failure);
  final ResetFailure failure;
}

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

  /// Signs in. True when this sign-in cancelled a pending account deletion (the 30-day grace period).
  Future<bool> signIn(String email, String password);

  /// Cancels a pending account deletion of the signed-in user (a sign-in that could not reach the server left it
  /// standing). True when one was cancelled. Never throws.
  Future<bool> reactivateIfPending();

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

  /// Asks to delete the account after checking [password] again (server side): it is removed with all its data after
  /// 30 days unless the person signs in again before then. Signs out on success.
  /// Throws [DeleteAccountException].
  Future<void> deleteAccount(String password);

  /// Checks [current] first, then sets [next]. Throws [PasswordException].
  Future<void> changePassword({required String current, required String next});

  /// Emails a reset link. Succeeds the same way whether or not the address has an account (no account lookup for
  /// strangers). Throws [ResetException] for a rate limit or no connection.
  Future<void> sendPasswordReset(String email);

  /// Fires when the person opens the emailed reset link: the app now holds a short-lived session meant only for
  /// choosing a new password.
  Stream<void> get passwordRecovery;

  /// Sets a new password after a reset link, without asking for the old one. Throws [PasswordException].
  Future<void> setNewPassword(String next);
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
  Future<bool> signIn(String email, String password) async {
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
    // Signing in cancels a pending deletion. If the call fails the app asks again every time it opens (see
    // ShellPage), and the server never purges an account that signed in after asking to be deleted.
    return reactivateIfPending();
  }

  /// "Your account is active again" mail. A courtesy and a warning if it was not the owner: never awaited, never
  /// allowed to fail the sign-in.
  void _mailReactivated() {
    _client.functions
        .invoke('send-account-email', body: {'kind': 'reactivated'})
        .then<void>((_) {}, onError: (_) {});
  }

  @override
  Future<bool> reactivateIfPending() async {
    // Only right after a password sign-in: an older session (another device, still valid for up to an hour after a
    // deletion request) must not cancel a deletion. The server never purges an account that signed in after asking.
    final last = DateTime.tryParse(
      _client.auth.currentUser?.lastSignInAt ?? '',
    );
    if (last == null || DateTime.now().difference(last).inMinutes > 15) {
      return false;
    }
    try {
      final was = await _client.rpc('reactivate_my_account') == true;
      if (was) _mailReactivated();
      return was;
    } catch (_) {
      return false;
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
        emailRedirectTo: AppConfig.authRedirect,
      );
      // With "confirm email" on, a registered address comes back as a user with no identities and no error.
      if (res.user != null && (res.user!.identities ?? const []).isEmpty) {
        throw const SignUpException(SignUpFailure.emailTaken);
      }
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
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
          throw const SignUpException(SignUpFailure.tryLater);
      }
      // Any other answer from the server (including a 5xx) is "try later", not "no connection".
      throw const SignUpException(SignUpFailure.tryLater);
    } on SignUpException {
      rethrow;
    } catch (_) {
      throw const SignUpException(SignUpFailure.network);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppConfig.authRedirect,
      );
    } on AuthApiException catch (e) {
      if (e.code == 'over_email_send_rate_limit' ||
          e.code == 'over_request_rate_limit' ||
          e.statusCode == '429') {
        throw const ResetException(ResetFailure.tryLater);
      }
      throw const ResetException(ResetFailure.tryLater);
    } catch (_) {
      throw const ResetException(ResetFailure.network);
    }
  }

  @override
  Stream<void> get passwordRecovery => _client.auth.onAuthStateChange
      .where((e) => e.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<void> setNewPassword(String next) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: next));
    } on AuthWeakPasswordException {
      throw const PasswordException(PasswordFailure.tooShort);
    } on AuthApiException catch (e) {
      if (e.code == 'weak_password' || e.code == 'same_password') {
        throw const PasswordException(PasswordFailure.tooShort);
      }
      throw const PasswordException(PasswordFailure.network);
    } catch (_) {
      throw const PasswordException(PasswordFailure.network);
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
  Future<void> deleteAccount(String password) async {
    try {
      await _client.functions.invoke(
        'delete-account',
        body: {'password': password},
      );
    } on FunctionException catch (e) {
      // 401: the account is already gone (an earlier try deleted it and its answer was lost) or the session is no
      // longer valid. Either way there is nothing left to delete, so carry on and clean this phone up.
      if (e.status == 401) {
        try {
          await _client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}
        return;
      }
      if (e.status == 403) {
        throw const DeleteAccountException(DeleteFailure.wrongPassword);
      }
      if (e.status == 429) {
        throw const DeleteAccountException(DeleteFailure.tooMany);
      }
      throw const DeleteAccountException(DeleteFailure.network);
    } catch (_) {
      throw const DeleteAccountException(DeleteFailure.network);
    }
    // The account is gone; the session is already useless, so a failing sign-out here is harmless.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
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
      // The current password goes along so the server can check it too (Supabase: "Require current password when
      // updating"), not only this screen.
      await _client.auth.updateUser(
        UserAttributes(password: next, currentPassword: current),
      );
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
