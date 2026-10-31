import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

final transactionsProvider = FutureProvider.autoDispose<List<Txn>>(
  (ref) => ref.watch(dataRepositoryProvider).recentTransactions(),
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
