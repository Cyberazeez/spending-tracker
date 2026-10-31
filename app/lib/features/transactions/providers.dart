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

final categoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(dataRepositoryProvider).categories(),
  retry: (_, _) => null,
);

final needsReviewProvider = FutureProvider.autoDispose<List<RawMessage>>(
  (ref) => ref.watch(dataRepositoryProvider).needsReview(),
  retry: (_, _) => null,
);

final senderGapsProvider = FutureProvider.autoDispose<List<SenderGap>>(
  (ref) => ref.watch(dataRepositoryProvider).senderGaps(),
  retry: (_, _) => null,
);
