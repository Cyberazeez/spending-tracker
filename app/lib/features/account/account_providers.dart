import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/capture_bridge.dart';
import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../insights/providers.dart';

/// The user's own accounts (Account > Bank accounts).
final ownAccountsProvider = FutureProvider.autoDispose<List<OwnAccount>>(
  (ref) => ref.watch(dataRepositoryProvider).ownAccounts(),
  retry: (_, _) => null,
);

String _collapsedKey(String? userId) => 'welcome_collapsed_${userId ?? 'none'}';
String _firstSeenKey(String? userId) => 'welcome_first_${userId ?? 'none'}';

/// The welcome card removes itself this many days after it was first shown if it is still not finished.
const welcomeLifetimeDays = 3;

class WelcomeUi {
  const WelcomeUi({required this.collapsed, this.firstSeen});
  final bool collapsed;
  final DateTime? firstSeen;
}

/// "Hide" folds the card into one line instead of removing it; tapping the line opens it again. Remembered per
/// account on this phone, together with the day the card was first shown (it expires after [welcomeLifetimeDays]).
final welcomeProvider = NotifierProvider<WelcomeController, WelcomeUi>(
  WelcomeController.new,
);

class WelcomeController extends Notifier<WelcomeUi> {
  String? get _uid => ref.read(authRepositoryProvider).userId;

  @override
  WelcomeUi build() {
    // Re-read whenever somebody signs in or out, so a second account on this phone starts with its own card.
    ref.watch(signedInProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final first = prefs.getString(_firstSeenKey(_uid));
    return WelcomeUi(
      collapsed: prefs.getBool(_collapsedKey(_uid)) ?? false,
      firstSeen: first == null ? null : DateTime.tryParse(first),
    );
  }

  Future<void> setCollapsed(bool value) async {
    state = WelcomeUi(collapsed: value, firstSeen: state.firstSeen);
    await ref.read(sharedPrefsProvider).setBool(_collapsedKey(_uid), value);
  }

  /// Called when the card is first shown: starts its lifetime.
  Future<void> markSeen() async {
    if (state.firstSeen != null) return;
    final now = ref.read(clockProvider)();
    state = WelcomeUi(collapsed: state.collapsed, firstSeen: now);
    await ref
        .read(sharedPrefsProvider)
        .setString(_firstSeenKey(_uid), now.toIso8601String());
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

/// Whether the welcome card shows on Home: not finished and not older than [welcomeLifetimeDays].
final welcomeVisibleProvider = Provider.autoDispose<bool>((ref) {
  if (ref.watch(welcomeStateProvider).allDone) return false;
  final seen = ref.watch(welcomeProvider).firstSeen;
  if (seen == null) return true;
  final age = ref.watch(clockProvider)().difference(seen);
  return age.inDays < welcomeLifetimeDays;
});
