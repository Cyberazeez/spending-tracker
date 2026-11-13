import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/features/more/capture_label.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';

void main() {
  test('the last send is shown as words, not as "HTTP 200"', () async {
    final t = await AppLocalizations.delegate.load(const Locale('en'));
    expect(captureLastLabel(t, '11:20:28 HTTP 200'), contains('Last sent'));
    expect(captureLastLabel(t, '11:20:28 HTTP 200'), contains('11:20'));
    expect(captureLastLabel(t, '11:20:28 HTTP 200'), isNot(contains('HTTP')));
    expect(captureLastLabel(t, '9:05 HTTP 500'), 'Last send failed (500)');
    expect(captureLastLabel(t, 'something else'), 'something else');
    expect(captureLastLabel(t, ''), '');
    // The phone's other log entries are words too, never raw codes.
    expect(captureLastLabel(t, '19:55:13 error -1009'), 'No connection');
    expect(captureLastLabel(t, '19:55:13 no response'), 'No connection');
    expect(captureLastLabel(t, '19:55:13 queued'), 'Waiting to send');
    expect(captureLastLabel(t, '19:55:13 no token'), 'Not set up yet');
  });
}
