import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widget_bridge.dart';
import 'metrics.dart';

final insightsProvider = FutureProvider.autoDispose<Insights>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  final txns = await repo.spendingHistory();
  final cats = await repo.categories();
  return computeInsights(
    txns,
    ref.watch(clockProvider)(),
    excludedCategories: {
      for (final c in cats)
        if (c.excludedFromSpend) c.id,
    },
  );
}, retry: (_, _) => null);

final todaySpendProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(dataRepositoryProvider).todaySpendHalalas(),
  retry: (_, _) => null,
);

final monthlyBudgetProvider = FutureProvider.autoDispose<int?>(
  (ref) => ref.watch(dataRepositoryProvider).monthlyBudgetHalalas(),
  retry: (_, _) => null,
);

/// The numbers the home-screen widget shows, recomputed whenever any of them is refreshed.
final widgetSnapshotProvider = FutureProvider.autoDispose<WidgetSnapshot>((
  ref,
) async {
  final insights = await ref.watch(insightsProvider.future);
  final today = await ref.watch(todaySpendProvider.future);
  final budget = await ref.watch(monthlyBudgetProvider.future);
  return WidgetSnapshot(
    todayHalalas: today,
    monthHalalas: insights.monthSpend,
    budgetHalalas: budget,
    language: ref.watch(localeProvider).languageCode,
  );
}, retry: (_, _) => null);

final budgetsProvider = FutureProvider.autoDispose<List<Budget>>(
  (ref) => ref.watch(dataRepositoryProvider).budgets(),
  retry: (_, _) => null,
);
