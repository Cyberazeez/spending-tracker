import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// The version of the Terms of Use and Privacy Policy a person agrees to when creating an account. Change it when
/// either text changes in a way that needs a new agreement; it is stored with the account.
const legalVersion = '2026-11-10';

const _site = 'https://halala.rawafiddata.com';

enum LegalPage { terms, privacy, support }

/// The public page in the app language (the Arabic pages live under /ar/, support has an Arabic section).
Uri legalUri(LegalPage page, Locale locale) {
  final ar = locale.languageCode == 'ar';
  return switch (page) {
    LegalPage.terms => Uri.parse('$_site/terms/${ar ? 'ar/' : ''}'),
    LegalPage.privacy => Uri.parse('$_site/privacy/${ar ? 'ar/' : ''}'),
    LegalPage.support => Uri.parse('$_site/support/${ar ? '#ar' : ''}'),
  };
}

/// Opens a web page outside the app. A seam so tests do not launch anything.
abstract class UrlOpener {
  Future<void> open(Uri uri);
}

class LaunchUrlOpener implements UrlOpener {
  const LaunchUrlOpener();

  @override
  Future<void> open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing to show: the page simply does not open.
    }
  }
}

final urlOpenerProvider = Provider<UrlOpener>((ref) => const LaunchUrlOpener());
