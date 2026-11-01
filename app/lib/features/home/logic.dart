import '../../core/models.dart';

/// Days with no SMS at all, or null when nothing has ever arrived (that is the empty state, not a warning).
/// Only a gap of [after] days or more counts as silence.
int? silentDays(List<SenderGap> gaps, DateTime now, {int after = 3}) {
  DateTime? latest;
  for (final g in gaps) {
    final t = g.lastReceivedAt;
    if (t != null && (latest == null || t.isAfter(latest))) latest = t;
  }
  if (latest == null) return null;
  final days = now.toUtc().difference(latest).inDays;
  return days >= after ? days : null;
}
