import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/capture_bridge.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../insights/providers.dart';

/// The user's own accounts (Account > Bank accounts).
final ownAccountsProvider = FutureProvider.autoDispose<List<OwnAccount>>(
  (ref) => ref.watch(dataRepositoryProvider).ownAccounts(),
  retry: (_, _) => null,
);

String _hiddenKey(String? userId) => 'welcome_hidden_${userId ?? 'none'}';

/// "Hide" on the welcome card, remembered per account on this phone.
final welcomeHiddenProvider = NotifierProvider<WelcomeHidden, bool>(
  WelcomeHidden.new,
);

class WelcomeHidden extends Notifier<bool> {
  @override
  bool build() {
    // Re-read whenever somebody signs in or out, so a second account on this phone starts with its own card.
    ref.watch(signedInProvider);
    final uid = ref.read(authRepositoryProvider).userId;
    return ref.read(sharedPrefsProvider).getBool(_hiddenKey(uid)) ?? false;
  }

  Future<void> hide() async {
    state = true;
    final uid = ref.read(authRepositoryProvider).userId;
    await ref.read(sharedPrefsProvider).setBool(_hiddenKey(uid), true);
  }
}

/// The three first steps of a new account and which are done. While an answer is still loading its step counts as
/// done, so the card waits for real answers before it shows.
class WelcomeState {
  const WelcomeState({
    required this.accounts,
    required this.capture,
    required this.budget,
  });

  final bool accounts;
  final bool capture;
  final bool budget;

  int get done => [accounts, capture, budget].where((x) => x).length;
  bool get allDone => done == 3;
}

final welcomeStateProvider = Provider.autoDispose<WelcomeState>((ref) {
  final accounts = ref.watch(ownAccountsProvider);
  final budget = ref.watch(monthlyBudgetProvider);
  final capture = ref.watch(captureStatusProvider);
  return WelcomeState(
    accounts: accounts.isLoading || accounts.hasError
        ? true
        : (accounts.value ?? const []).isNotEmpty,
    capture: capture.isLoading || capture.hasError
        ? true
        : capture.value!.last.isNotEmpty,
    budget: budget.isLoading || budget.hasError ? true : budget.value != null,
  );
});

/// Whether the welcome card shows on Home.
final welcomeVisibleProvider = Provider.autoDispose<bool>(
  (ref) =>
      !ref.watch(welcomeHiddenProvider) &&
      !ref.watch(welcomeStateProvider).allDone,
);
