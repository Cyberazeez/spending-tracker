import '../../core/models.dart';
import '../insights/metrics.dart';

const _maxCategories = 25;
const _maxAmount = 10000000000; // 100 million SAR, the server's ceiling

int _clamp(int v) => v < 0 ? 0 : (v > _maxAmount ? _maxAmount : v);

/// The month's totals in the shape the `insights-tips` function accepts: numbers and the user's own category
/// names only. No merchants, no SMS text, no account numbers. Returns null when there is nothing to talk about.
Map<String, dynamic>? buildAiAggregates(
  Insights ins,
  List<Category> cats,
  List<Budget> budgets,
  DateTime today,
) {
  if (!ins.hasData) return null;
  final byId = {for (final c in cats) c.id: c};
  final budgetOf = {for (final b in budgets) b.categoryId: b.limitHalalas};
  final spent = <String, int>{
    for (final c in ins.byCategory)
      if (c.categoryId != null && byId.containsKey(c.categoryId))
        c.categoryId!: c.halalas,
  };
  final ids = {
    ...spent.keys,
    for (final e in ins.average3.entries)
      if (e.key != null && byId.containsKey(e.key)) e.key!,
  };
  final rows = [
    for (final id in ids)
      if ((spent[id] ?? 0) != 0 || (ins.average3[id] ?? 0) > 0)
        (
          name: byId[id]!.name,
          spent: spent[id] ?? 0,
          avg: _clamp(ins.average3[id] ?? 0),
          budget: budgetOf[id],
        ),
  ]..sort((a, b) => b.spent.compareTo(a.spent));
  final m = today.month.toString().padLeft(2, '0');
  final rate = ins.savingsRate;
  return {
    'month': '${today.year}-$m',
    'spendHalalas': ins.monthSpend.clamp(-_maxAmount, _maxAmount),
    'lastMonthToDateHalalas': _clamp(ins.lastMonthToDate),
    'savingsRatePct': rate == null
        ? null
        : (rate * 100).round().clamp(-1000, 1000),
    'salaryAboveBase': ins.salaryAboveBase,
    'subscriptionsMonthlyHalalas': _clamp(ins.subscriptionsMonthly),
    'categories': [
      for (final r in rows.take(_maxCategories))
        {
          'name': r.name,
          'spentHalalas': r.spent.clamp(-_maxAmount, _maxAmount),
          'avg3Halalas': r.avg,
          'budgetHalalas': r.budget == null ? null : _clamp(r.budget!),
        },
    ],
  };
}
