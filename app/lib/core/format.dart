import 'package:intl/intl.dart';

/// Riyadh is UTC+3 all year. Western digits and 24-hour time in every language.
DateTime toRiyadh(DateTime t) => t.toUtc().add(const Duration(hours: 3));

/// Wrapped in left-to-right isolates so the Latin date does not reorder inside Arabic sentences.
String formatDateTime(DateTime t) =>
    '\u2066${DateFormat('d MMM HH:mm', 'en').format(toRiyadh(t))}\u2069';

const _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _monthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Month name for a Riyadh calendar date (held as UTC midnight).
String monthName(DateTime d, {required bool arabic}) =>
    (arabic ? _monthsAr : _monthsEn)[d.month - 1];

/// A Riyadh calendar date held as UTC midnight, e.g. "2 Nov".
String formatDay(DateTime d) =>
    '\u2066${DateFormat('d MMM', 'en').format(d.toUtc())}\u2069';

/// Keeps a number or amount in left-to-right order inside a sentence of another direction (Arabic).
String ltrIsolate(String s) => '\u2066$s\u2069';
