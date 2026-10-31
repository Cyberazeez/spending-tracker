import 'package:intl/intl.dart';

/// Riyadh is UTC+3 all year. Western digits and 24-hour time in every language.
DateTime toRiyadh(DateTime t) => t.toUtc().add(const Duration(hours: 3));

/// Wrapped in left-to-right isolates so the Latin date does not reorder inside Arabic sentences.
String formatDateTime(DateTime t) =>
    '\u2066${DateFormat('d MMM HH:mm', 'en').format(toRiyadh(t))}\u2069';

/// A Riyadh calendar date held as UTC midnight, e.g. "2 Nov".
String formatDay(DateTime d) =>
    '\u2066${DateFormat('d MMM', 'en').format(d.toUtc())}\u2069';
