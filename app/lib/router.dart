import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/lock.dart';
import 'core/providers.dart';
import 'features/ai/ai_chat_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/forgot_password_page.dart';
import 'features/auth/reset_password_page.dart';
import 'features/auth/signup_page.dart';
import 'features/auth/lock_page.dart';
import 'features/more/capture_page.dart';
import 'features/obligations/obligation_form_page.dart';
import 'features/account/account_pages.dart';
import 'features/account/delete_account_page.dart';
import 'features/account/own_accounts_page.dart';
import 'features/transactions/quick_add_page.dart';
import 'features/transactions/review_page.dart';
import 'features/shell/shell_page.dart';
import 'core/models.dart' show Txn;
import 'features/transactions/transaction_page.dart';

const loginPath = '/login';
const lockPath = '/lock';
const signUpPath = '/signup';
const forgotPath = '/forgot';
const resetPath = '/reset';
const homePath = '/home';
const accountPath = '/home/account';
const profilePath = '/home/account/profile';
const securityPath = '/home/account/security';
const privacyPath = '/home/account/privacy';
const banksPath = '/home/account/banks';
const deleteAccountPath = '/home/account/privacy/delete';
const quickAddPath = '/home/quick-add';

/// One transaction's details; push it with the [Txn] as `extra`.
const txnPath = '/home/txn';
const reviewPath = '/home/review';
const capturePath = '/home/capture';
const obligationFormPath = '/home/obligation';
const aiChatPath = '/home/ai-chat';

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
  bool recovery = false,
}) {
  if (!hasSession) {
    return location == loginPath ||
            location == signUpPath ||
            location == forgotPath
        ? null
        : loginPath;
  }
  // Opened from the reset-password email: only the new-password screen, until a password is set.
  if (recovery) return location == resetPath ? null : resetPath;
  if (locked) return location == lockPath ? null : lockPath;
  if (location == loginPath ||
      location == lockPath ||
      location == signUpPath ||
      location == forgotPath ||
      location == resetPath ||
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
  // The reset link proves the person owns the email address, so no Face ID prompt before choosing a new password.
  ref.listen(passwordRecoveryProvider, (_, next) {
    if (!next.hasValue) return;
    ref.read(lockProvider.notifier).markUnlocked();
    ref.read(recoveryPendingProvider.notifier).set(true);
    refresh.value++;
  });
  ref.listen(authLinkFailedProvider, (_, next) {
    if (next.hasValue) ref.read(linkFailedPendingProvider.notifier).set(true);
  });
  ref.listen(recoveryPendingProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: homePath,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      hasSession: ref.read(authRepositoryProvider).hasSession,
      locked: ref.read(lockProvider).locked,
      location: state.matchedLocation,
      recovery: ref.read(recoveryPendingProvider),
    ),
    routes: [
      GoRoute(path: loginPath, builder: (_, _) => const LoginPage()),
      GoRoute(path: lockPath, builder: (_, _) => const LockPage()),
      GoRoute(
        path: signUpPath,
        pageBuilder: (_, state) => _page(state, const SignUpPage()),
      ),
      GoRoute(
        path: forgotPath,
        pageBuilder: (_, state) => _page(state, const ForgotPasswordPage()),
      ),
      GoRoute(path: resetPath, builder: (_, _) => const ResetPasswordPage()),
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
                path: 'banks',
                pageBuilder: (_, state) =>
                    _page(state, const OwnAccountsPage()),
              ),
              GoRoute(
                path: 'privacy',
                pageBuilder: (_, state) => _page(state, const PrivacyPage()),
                routes: [
                  GoRoute(
                    path: 'delete',
                    pageBuilder: (_, state) =>
                        _page(state, const DeleteAccountPage()),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'txn',
            pageBuilder: (_, state) => _page(
              state,
              // Opened without its transaction (a link): back to the list.
              state.extra is Txn
                  ? TransactionPage(txn: state.extra! as Txn)
                  : const MissingTransactionPage(),
            ),
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
            path: 'ai-chat',
            pageBuilder: (_, state) => _page(state, const AiChatPage()),
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
