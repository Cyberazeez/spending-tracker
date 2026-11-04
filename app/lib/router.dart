import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/lock.dart';
import 'core/providers.dart';
import 'features/auth/login_page.dart';
import 'features/auth/signup_page.dart';
import 'features/auth/lock_page.dart';
import 'features/more/capture_page.dart';
import 'features/obligations/obligation_form_page.dart';
import 'features/account/account_pages.dart';
import 'features/transactions/quick_add_page.dart';
import 'features/transactions/review_page.dart';
import 'features/shell/shell_page.dart';

const loginPath = '/login';
const lockPath = '/lock';
const signUpPath = '/signup';
const homePath = '/home';
const accountPath = '/home/account';
const profilePath = '/home/account/profile';
const securityPath = '/home/account/security';
const privacyPath = '/home/account/privacy';
const quickAddPath = '/home/quick-add';
const reviewPath = '/home/review';
const capturePath = '/home/capture';
const obligationFormPath = '/home/obligation';

/// Back from a sub-screen: pops it (animated, same as the swipe), or goes Home if it was opened directly.
void popOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(homePath);
  }
}

/// Sub-screens use iOS page transitions so the swipe from the left edge goes back.
Page<void> _page(GoRouterState state, Widget child) =>
    CupertinoPage<void>(key: state.pageKey, child: child);

/// Pure redirect rule, kept separate so it is easy to test.
String? redirectFor({
  required bool hasSession,
  required bool locked,
  required String location,
}) {
  if (!hasSession) {
    return location == loginPath || location == signUpPath ? null : loginPath;
  }
  if (locked) return location == lockPath ? null : lockPath;
  if (location == loginPath ||
      location == lockPath ||
      location == signUpPath ||
      location == '/') {
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
        path: signUpPath,
        pageBuilder: (_, state) => _page(state, const SignUpPage()),
      ),
      GoRoute(
        path: homePath,
        builder: (_, _) => const ShellPage(),
        routes: [
          GoRoute(
            path: 'account',
            pageBuilder: (_, state) => _page(state, const AccountPage()),
            routes: [
              GoRoute(
                path: 'profile',
                pageBuilder: (_, state) => _page(state, const ProfilePage()),
              ),
              GoRoute(
                path: 'security',
                pageBuilder: (_, state) => _page(state, const SecurityPage()),
              ),
              GoRoute(
                path: 'privacy',
                pageBuilder: (_, state) => _page(state, const PrivacyPage()),
              ),
            ],
          ),
          GoRoute(
            path: 'quick-add',
            pageBuilder: (_, state) => _page(state, const QuickAddPage()),
          ),
          GoRoute(
            path: 'review',
            pageBuilder: (_, state) => _page(state, const ReviewPage()),
          ),
          GoRoute(
            path: 'capture',
            pageBuilder: (_, state) => _page(state, const CapturePage()),
          ),
          GoRoute(
            path: 'obligation',
            pageBuilder: (_, state) => _page(
              state,
              ObligationFormPage(obligationId: state.uri.queryParameters['id']),
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
