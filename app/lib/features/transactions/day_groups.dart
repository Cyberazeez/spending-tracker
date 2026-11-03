import 'dart:math' as math;

import '../../core/models.dart';
import '../insights/metrics.dart' show spendOf;
import '../obligations/logic.dart' show riyadhToday;

/// One Riyadh calendar day of transactions and what was spent that day (same spend rule as the month total).
class DayGroup {
  const DayGroup(this.day, this.items, this.spendHalalas);

  /// The Riyadh date at UTC midnight, like `riyadhToday`.
  final DateTime day;
  final List<Txn> items;
  final int spendHalalas;
}

/// Splits a newest-first list into days, keeping the order. A day's total never shows below 0.
List<DayGroup> groupByDay(List<Txn> list) {
  final order = <DateTime>[];
  final items = <DateTime, List<Txn>>{};
  final spend = <DateTime, int>{};
  for (final t in list) {
    final d = riyadhToday(t.occurredAt);
    if (!items.containsKey(d)) order.add(d);
    items.putIfAbsent(d, () => []).add(t);
    spend[d] = (spend[d] ?? 0) + spendOf(t);
  }
  return [
    for (final d in order) DayGroup(d, items[d]!, math.max(0, spend[d]!)),
  ];
}
