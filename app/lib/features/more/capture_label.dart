import '../../l10n/app_localizations.dart';

/// The bridge reports the last send as "19:02:11 HTTP 200". Show it as words: "Last sent 19:02", or that it failed.
/// A string in any other shape is shown as it is.
String captureLastLabel(AppLocalizations t, String last) {
  final m = RegExp(r'^(\d{1,2}:\d{2})(?::\d{2})?\s+HTTP\s+(\d{3})$')
      .firstMatch(last.trim());
  if (m == null) return last;
  final code = int.parse(m.group(2)!);
  return code >= 200 && code < 300
      ? t.captureLastOk('\u2066${m.group(1)}\u2069')
      : t.captureLastFailed(code.toString());
}

/// Whether the last send succeeded: true for an HTTP 2xx ("19:02:11 HTTP 200"), null when nothing was sent yet, false
/// otherwise (another HTTP code, or a network error such as "19:55:13 error -1009").
bool? captureLastSucceeded(String last) {
  final l = last.trim();
  if (l.isEmpty) return null;
  final m = RegExp(r'HTTP\s+(\d{3})').firstMatch(l);
  if (m == null) return false;
  final code = int.parse(m.group(1)!);
  return code >= 200 && code < 300;
}
