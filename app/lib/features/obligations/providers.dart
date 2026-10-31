import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

/// Refreshes the server-side schedule first (best effort), then loads the instances.
final obligationsProvider =
    FutureProvider.autoDispose<List<ObligationInstance>>((ref) async {
      final repo = ref.watch(dataRepositoryProvider);
      try {
        await repo.refreshObligations();
      } catch (_) {
        // Offline or not yet migrated: show what is already stored.
      }
      return repo.obligationInstances();
    }, retry: (_, _) => null);

final monthSpendProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(dataRepositoryProvider).monthSpendHalalas(),
  retry: (_, _) => null,
);
