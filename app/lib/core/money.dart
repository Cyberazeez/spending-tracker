import 'package:intl/intl.dart';

/// The Saudi riyal sign (Unicode 17). iOS has no system font for it yet, so the app bundles one
/// ([riyalFont]); text that leaves the app (notifications) uses the letters instead.
const riyalSign = '\u20C1';
const riyalFont = 'SaudiRiyal';

/// Western digits in every language, the riyal sign before the number in English and after it in Arabic.
/// [symbol] false gives "SAR" / "ر.س" for places that cannot draw the sign.
String formatSar(int halalas, {required bool arabic, bool symbol = true}) {
  final whole = NumberFormat('#,##0', 'en').format(halalas.abs() ~/ 100);
  final frac = (halalas.abs() % 100).toString().padLeft(2, '0');
  final n = '$whole.$frac';
  final neg = halalas < 0
      ? '-'
      : ''; // a net-negative total (refunds above spend) keeps its sign
  if (symbol) return arabic ? '$neg$n $riyalSign' : '$neg$riyalSign $n';
  return arabic ? '$neg$n ر.س' : '${neg}SAR $n';
}

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// "25", "25.5", "1,250.50", "٢٥٫٥" -> halalas, or null when it is not a valid positive amount.
/// Commas are thousands separators only: "12,50" is rejected rather than read as 1,250.
int? parseHalalas(String input) {
  var s = input.trim().replaceAll('٫', '.').replaceAll('٬', ',');
  s = s.replaceAllMapped(
    RegExp('[٠-٩]'),
    (m) => _arabicDigits.indexOf(m[0]!).toString(),
  );
  final valid = RegExp(r'^(\d{1,10}|\d{1,3}(,\d{3})+)(\.\d{1,2})?$');
  if (!valid.hasMatch(s)) return null;
  final parts = s.replaceAll(',', '').split('.');
  final h =
      int.parse(parts[0]) * 100 +
      (parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return h > 0 ? h : null;
}

/// Best-effort amount in a bank SMS that no parser understood, to prefill "Add as transaction": the number written
/// next to the riyal ("384 SAR", "SAR 384.50", "384 ر.س"). Null when there is none, or two different ones (for
/// example a balance next to the amount), so the person types it instead of confirming a wrong guess.
String? guessAmountFromSms(String body) {
  final text = body
      .replaceAll('٫', '.')
      .replaceAll('٬', ',')
      .replaceAllMapped(
        RegExp('[٠-٩]'),
        (m) => _arabicDigits.indexOf(m[0]!).toString(),
      );
  const number = r'(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)';
  const unit = r'(?:SAR|SR|ر\.?\s?س|ريال)';
  final found = <int, String>{};
  for (final re in [
    RegExp('$number\\s*$unit', caseSensitive: false),
    RegExp('$unit\\s*:?\\s*$number', caseSensitive: false),
  ]) {
    for (final m in re.allMatches(text)) {
      final raw = m.group(1)!;
      final halalas = parseHalalas(raw);
      if (halalas != null) found[halalas] = raw;
    }
  }
  return found.length == 1 ? found.values.first : null;
}
