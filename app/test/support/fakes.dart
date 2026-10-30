import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spending_tracker/app.dart';
import 'package:spending_tracker/core/auth_repository.dart';
import 'package:spending_tracker/core/lock.dart';
import 'package:spending_tracker/core/providers.dart';
import 'package:spending_tracker/core/token_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._signedIn = false});

  bool _signedIn;
  final _controller = StreamController<bool>.broadcast();
  SignInFailure? failWith;
  int signInCalls = 0;

  @override
  bool get hasSession => _signedIn;

  @override
  Stream<bool> get signedIn => _controller.stream;

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    if (failWith != null) throw SignInException(failWith!);
    _signedIn = true;
    _controller.add(true);
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _controller.add(false);
  }
}

class FakeAuthenticator implements Authenticator {
  bool result = true;
  bool throws = false;
  int calls = 0;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    if (throws) throw StateError('platform error');
    return result;
  }
}

class FakeTokenRepository implements TokenRepository {
  IngestTokenInfo? active;
  int rotateCalls = 0;
  int loadCalls = 0;
  bool failLoad = false;

  @override
  Future<IngestTokenInfo?> activeToken() async {
    loadCalls++;
    if (failLoad) throw StateError('offline');
    return active;
  }

  @override
  Future<String> rotate({String label = 'iPhone'}) async {
    rotateCalls++;
    active = IngestTokenInfo(
      label: label,
      createdAt: DateTime.utc(2026, 10, 30, 12),
    );
    return 'stk_TESTTOKEN';
  }
}

class Harness {
  Harness({bool signedIn = false})
    : auth = FakeAuthRepository(signedIn: signedIn),
      authenticator = FakeAuthenticator(),
      tokens = FakeTokenRepository();

  final FakeAuthRepository auth;
  final FakeAuthenticator authenticator;
  final FakeTokenRepository tokens;
  DateTime now = DateTime.utc(2026, 10, 30, 12);

  Future<ProviderScope> build({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        authenticatorProvider.overrideWithValue(authenticator),
        tokenRepositoryProvider.overrideWithValue(tokens),
        sharedPrefsProvider.overrideWithValue(sp),
        clockProvider.overrideWithValue(() => now),
      ],
      child: const SpendingTrackerApp(),
    );
  }
}
