import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

class TxFilterController extends Notifier<TxFilter> {
  @override
  TxFilter build() => const TxFilter();
  void set(TxFilter f) => state = f;
  void clear() => state = const TxFilter();
}

final txFilterProvider = NotifierProvider<TxFilterController, TxFilter>(
  TxFilterController.new,
);

final transactionsProvider = FutureProvider.autoDispose<List<Txn>>(
  (ref) => ref
      .watch(dataRepositoryProvider)
      .recentTransactions(filter: ref.watch(txFilterProvider)),
  retry: (_, _) => null,
);

/// How many spends have no category in total (the Activity list only holds the latest 200, or a filtered set).
final uncategorizedCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(
    transactionsProvider,
  ); // recount whenever the list reloads (after a category change or AI run)
  return ref.watch(dataRepositoryProvider).uncategorizedSpendCount();
}, retry: (_, _) => null);

final categoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(dataRepositoryProvider).categories(),
  retry: (_, _) => null,
);

final needsReviewProvider = FutureProvider.autoDispose<List<RawMessage>>(
  (ref) => ref.watch(dataRepositoryProvider).needsReview(),
  retry: (_, _) => null,
);

/// Messages the AI read that wait for the person to say "looks right" (or "wrong").
final aiReadProvider = FutureProvider.autoDispose<List<AiRead>>(
  (ref) => ref.watch(dataRepositoryProvider).aiReadToCheck(),
  retry: (_, _) => null,
);

/// Everything waiting for the person in the inbox: messages nobody could read plus AI readings to check.
final reviewCountProvider = Provider.autoDispose<int>(
  (ref) =>
      (ref.watch(needsReviewProvider).value?.length ?? 0) +
      (ref.watch(aiReadProvider).value?.length ?? 0),
);

final senderGapsProvider = FutureProvider.autoDispose<List<SenderGap>>(
  (ref) => ref.watch(dataRepositoryProvider).senderGaps(),
  retry: (_, _) => null,
);

/// Whether the account has any transaction at all (every month): tells an empty month apart from a new account.
final anyTransactionsProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(transactionsProvider);
  final n = await ref
      .watch(dataRepositoryProvider)
      .countTransactions(const TxFilter(period: TxPeriod.all));
  return n > 0;
}, retry: (_, _) => null);
