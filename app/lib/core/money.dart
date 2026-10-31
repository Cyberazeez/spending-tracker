import 'package:intl/intl.dart';

/// Western digits in every language, SAR shown before the number in English and after it in Arabic.
String formatSar(int halalas, {required bool arabic}) {
  final whole = NumberFormat('#,##0', 'en').format(halalas.abs() ~/ 100);
  final frac = (halalas.abs() % 100).toString().padLeft(2, '0');
  final n = '$whole.$frac';
  return arabic ? '$n ر.س' : 'SAR $n';
}

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// "25", "25.5", "1,250.50", "٢٥٫٥" -> halalas, or null when it is not a valid positive amount.
int? parseHalalas(String input) {
  var s = input
      .trim()
      .replaceAll(',', '')
      .replaceAll('٫', '.')
      .replaceAll('،', '');
  s = s.replaceAllMapped(
    RegExp('[٠-٩]'),
    (m) => _arabicDigits.indexOf(m[0]!).toString(),
  );
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) return null;
  final parts = s.split('.');
  final h =
      int.parse(parts[0]) * 100 +
      (parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return h > 0 ? h : null;
}
