import '../../l10n/app_localizations.dart';

/// What the last entry of the phone's capture log means. The native side records "HH:MM:SS queued" when a message
/// is queued, "no token" without credentials, "HTTP nnn" after a send, and "no response" / "error -1009" when the
/// network failed (the message stays queued and is retried).
enum CaptureResult { none, sent, failed, offline, queued, noToken, unknown }

final _http = RegExp(r'HTTP\s+(\d{3})');
final _time = RegExp(r'^(\d{1,2}:\d{2})(?::\d{2})?\b');

CaptureResult captureResult(String last) {
  final l = last.trim();
  if (l.isEmpty) return CaptureResult.none;
  final m = _http.firstMatch(l);
  if (m != null) {
    final code = int.parse(m.group(1)!);
    return code >= 200 && code < 300
        ? CaptureResult.sent
        : CaptureResult.failed;
  }
  if (l.endsWith('queued')) return CaptureResult.queued;
  if (l.endsWith('no token')) return CaptureResult.noToken;
  if (l.contains('no response') || RegExp(r'error\s+-?\d+').hasMatch(l)) {
    return CaptureResult.offline;
  }
  return CaptureResult.unknown;
}

/// The last capture log entry as words in the app language: "Last sent 19:02", "Last send failed (500)", "No
/// connection", "Waiting to send". A string in an unknown shape is shown as it is.
String captureLastLabel(AppLocalizations t, String last) {
  final time = _time.firstMatch(last.trim())?.group(1);
  return switch (captureResult(last)) {
    CaptureResult.none => '',
    CaptureResult.sent =>
      time == null ? t.capWorking : t.captureLastOk('\u2066$time\u2069'),
    CaptureResult.failed => t.captureLastFailed(
      _http.firstMatch(last)!.group(1)!,
    ),
    CaptureResult.offline => t.capOffline,
    CaptureResult.queued => t.capQueued,
    CaptureResult.noToken => t.capNotSetUp,
    CaptureResult.unknown => last,
  };
}
