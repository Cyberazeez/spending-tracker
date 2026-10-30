import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/lock.dart';
import 'core/providers.dart';
import 'features/auth/login_page.dart';
import 'features/auth/lock_page.dart';
import 'features/more/token_page.dart';
import 'features/shell/shell_page.dart';

const loginPath = '/login';
const lockPath = '/lock';
const homePath = '/home';
const tokenPath = '/home/token';

/// Pure redirect rule, kept separate so it is easy to test.
String? redirectFor({
  required bool hasSession,
  required bool locked,
  required String location,
}) {
  if (!hasSession) return location == loginPath ? null : loginPath;
  if (locked) return location == lockPath ? null : lockPath;
  if (location == loginPath || location == lockPath || location == '/') {
    return homePath;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(signedInProvider, (_, _) => refresh.value++);
  ref.listen(lockProvider, (prev, next) {
    if (prev?.locked != next.locked) refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: homePath,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      hasSession: ref.read(authRepositoryProvider).hasSession,
      locked: ref.read(lockProvider).locked,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: loginPath, builder: (_, _) => const LoginPage()),
      GoRoute(path: lockPath, builder: (_, _) => const LockPage()),
      GoRoute(
        path: homePath,
        builder: (_, _) => const ShellPage(),
        routes: [GoRoute(path: 'token', builder: (_, _) => const TokenPage())],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
