import '../../core/models.dart';
import '../obligations/logic.dart' show riyadhToday;

/// Largest budget the app accepts (100 million SAR), matching what the tips function will take.
const maxBudgetHalalas = 10000000000;

/// The salary the owner expects each month; anything above is flagged.
const baseSalaryHalalas = 1410000;

class CategorySpend {
  const CategorySpend(this.categoryId, this.halalas);
  final String? categoryId; // null = uncategorised
  final int halalas;
}

class MerchantSpend {
  const MerchantSpend(this.merchantNorm, this.label, this.halalas, this.count);
  final String merchantNorm;
  final String label;
  final int halalas;
  final int count;
}

class Spike {
  const Spike(this.categoryId, this.thisMonth, this.average);
  final String? categoryId;
  final int thisMonth;
  final int average;
}

class Subscription {
  const Subscription(this.merchantNorm, this.label, this.monthlyHalalas);
  final String merchantNorm;
  final String label;
  final int monthlyHalalas;
}

class Insights {
  const Insights({
    required this.monthSpend,
    required this.lastMonthToDate,
    required this.lastMonthHasData,
    required this.byCategory,
    required this.topMerchants,
    required this.average3,
    required this.spikes,
    required this.subscriptions,
    required this.salary,
    required this.savingsRate,
    required this.salaryAboveBase,
    required this.hasData,
  });

  final int monthSpend;

  /// Spend in the previous month up to the same day of the month as today.
  final int lastMonthToDate;

  /// Any spending was recorded in the same days of last month. False means "nothing to compare" (for example the
  /// app only started receiving messages recently), not "you spent nothing".
  final bool lastMonthHasData;
  final List<CategorySpend> byCategory;
  final List<MerchantSpend> topMerchants;

  /// Average monthly spend per category over the three months before this one.
  final Map<String?, int> average3;
  final List<Spike> spikes;
  final List<Subscription> subscriptions;
  final int salary;

  /// (salary - spend) / salary, or null when no salary arrived this month.
  final double? savingsRate;

  /// This month's salary is above [baseSalaryHalalas]: an anomaly worth a look.
  final bool salaryAboveBase;
  final bool hasData;

  int get subscriptionsMonthly =>
      subscriptions.fold(0, (s, x) => s + x.monthlyHalalas);
}

int _monthKey(DateTime d) => d.year * 12 + d.month;

/// What one transaction adds to spending: outgoing money that is neither internal nor excluded, minus refunds.
int spendOf(Txn t) {
  if (t.isInternal || t.excludedFromSpend) return 0;
  if (t.direction == 'out') return t.amountHalalas;
  if (t.type == 'refund') return -t.amountHalalas;
  return 0;
}

/// Everything here is computed from the transactions the app already holds; nothing leaves the phone.
Insights computeInsights(
  List<Txn> all,
  DateTime now, {
  int baseSalary = baseSalaryHalalas,

  /// Categories flagged "excluded from spend" (Transfers, Income): their money is not spending.
  Set<String> excludedCategories = const {},
}) {
  final today = riyadhToday(now);
  final thisKey = _monthKey(today);
  DateTime day(Txn t) => riyadhToday(t.occurredAt);

  var monthSpend = 0;
  var lastToDate = 0;
  var lastToDateRows = 0;
  var salary = 0;
  final cat = <String?, int>{};
  final merch = <String, ({String label, int sum, int n})>{};
  final prior = <String?, int>{}; // sum over the 3 previous full months
  final priorMonthsWithData = <int>{};
  final subCandidates = <String, Map<int, List<int>>>{};
  final subLabel = <String, String>{};

  for (final t in all) {
    final d = day(t);
    final key = _monthKey(d);
    final spend = excludedCategories.contains(t.categoryId) ? 0 : spendOf(t);
    if (key == thisKey) {
      monthSpend += spend;
      if (spend != 0) cat[t.categoryId] = (cat[t.categoryId] ?? 0) + spend;
      if (t.type == 'salary' && t.direction == 'in') {
        salary += t.amountHalalas;
      }
      final m = t.merchantNorm;
      if (spend > 0 && m != null && m.isNotEmpty) {
        final cur = merch[m];
        merch[m] = (
          label: cur?.label ?? (t.merchant ?? m),
          sum: (cur?.sum ?? 0) + spend,
          n: (cur?.n ?? 0) + 1,
        );
      }
    } else if (key == thisKey - 1 && d.day <= today.day) {
      lastToDate += spend;
      if (spend != 0) lastToDateRows++;
    }
    if (key < thisKey && key >= thisKey - 3 && spend != 0) {
      prior[t.categoryId] = (prior[t.categoryId] ?? 0) + spend;
      priorMonthsWithData.add(key);
    }
    // Subscription candidates: one outgoing purchase per merchant per month, over the last 4 months.
    if (t.direction == 'out' &&
        t.type == 'purchase' &&
        !t.isInternal &&
        key <= thisKey &&
        key >= thisKey - 3) {
      final m = t.merchantNorm;
      if (m != null && m.isNotEmpty) {
        subCandidates
            .putIfAbsent(m, () => {})
            .putIfAbsent(key, () => [])
            .add(t.amountHalalas);
        subLabel.putIfAbsent(m, () => t.merchant ?? m);
      }
    }
  }

  // A category can net below zero when its refunds outweigh its purchases; it is not listed then.
  final byCategory = [
    for (final e in cat.entries)
      if (e.value > 0) CategorySpend(e.key, e.value),
  ]..sort((a, b) => b.halalas.compareTo(a.halalas));

  final top = [
    for (final e in merch.entries)
      MerchantSpend(e.key, e.value.label, e.value.sum, e.value.n),
  ]..sort((a, b) => b.halalas.compareTo(a.halalas));

  final average3 = {
    for (final e in prior.entries)
      e.key: (e.value / priorMonthsWithData.length).round(),
  };

  final spikes = <Spike>[];
  if (priorMonthsWithData.isNotEmpty) {
    for (final c in byCategory) {
      final avg = average3[c.categoryId] ?? 0;
      if (avg > 0 && c.halalas > avg * 1.5 && c.halalas - avg >= 20000) {
        spikes.add(Spike(c.categoryId, c.halalas, avg));
      }
    }
  }

  final subs = <Subscription>[];
  subCandidates.forEach((m, months) {
    // Charged in at least 3 of the last 4 months, exactly once a month, with near-identical amounts.
    if (months.length < 3 || months.values.any((v) => v.length != 1)) return;
    final amounts = [for (final v in months.values) v.first]..sort();
    final median = amounts[amounts.length ~/ 2];
    if (amounts.every((a) => (a - median).abs() <= median * 0.1)) {
      subs.add(Subscription(m, subLabel[m] ?? m, median));
    }
  });
  subs.sort((a, b) => b.monthlyHalalas.compareTo(a.monthlyHalalas));

  return Insights(
    monthSpend: monthSpend,
    lastMonthToDate: lastToDate,
    lastMonthHasData: lastToDateRows > 0,
    byCategory: byCategory,
    topMerchants: top.take(5).toList(),
    average3: average3,
    spikes: spikes,
    subscriptions: subs,
    salary: salary,
    savingsRate: salary > 0 ? (salary - monthSpend) / salary : null,
    salaryAboveBase: salary > baseSalary,
    hasData: all.isNotEmpty,
  );
}

/// Share of the monthly budget spent, in whole percent (can pass 100); null when no budget is set.
int? budgetPercent(int spent, int? budget) =>
    (budget == null || budget <= 0) ? null : (spent * 100) ~/ budget;

enum BudgetLevel { ok, warn, over }

/// 80% of the limit warns, 100% is over.
BudgetLevel budgetLevel(int spent, int limit) {
  if (limit <= 0) return BudgetLevel.ok;
  if (spent >= limit) return BudgetLevel.over;
  if (spent * 100 >= limit * 80) return BudgetLevel.warn;
  return BudgetLevel.ok;
}

class BudgetAlert {
  const BudgetAlert(this.categoryId, this.level, this.percent);
  final String? categoryId;
  final BudgetLevel level;

  /// Share of the budget used, rounded down.
  final int percent;
}

/// Budgets at 80% or more of their limit this month, worst first.
List<BudgetAlert> budgetAlerts(Insights ins, List<Budget> budgets) {
  final out = <BudgetAlert>[];
  for (final c in ins.byCategory) {
    final id = c.categoryId;
    if (id == null) continue;
    final b = budgets.where((x) => x.categoryId == id).firstOrNull;
    if (b == null) continue;
    final level = budgetLevel(c.halalas, b.limitHalalas);
    if (level == BudgetLevel.ok) continue;
    out.add(BudgetAlert(id, level, (c.halalas * 100) ~/ b.limitHalalas));
  }
  out.sort((a, b) => b.percent.compareTo(a.percent));
  return out;
}
