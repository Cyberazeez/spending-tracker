import 'package:intl/intl.dart';

/// Riyadh is UTC+3 all year. Western digits and 24-hour time in every language.
DateTime toRiyadh(DateTime t) => t.toUtc().add(const Duration(hours: 3));

String formatDateTime(DateTime t) =>
    DateFormat('d MMM HH:mm', 'en').format(toRiyadh(t));
