/// Public client settings. The project URL and publishable key are meant to ship in the app;
/// access is enforced by row level security. Override per build with --dart-define.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://evepfssanoffnwtqjmyq.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ZmF7b-XpcsFn54t2HQWMRw_URDNC8nF',
  );

  /// Where the emailed links (confirm sign-up, reset password) send the person back to: the app's own URL scheme.
  /// Must be in Supabase > Authentication > URL Configuration > Redirect URLs.
  static const authRedirect = 'spendingtracker://auth';

  /// Google sign-in (Google Cloud project "Halala"). Public identifiers, not secrets: the iOS client opens Google's
  /// sheet, and the web client is the audience Supabase checks the ID token against. The iOS client's reversed ID is
  /// also a URL scheme in ios/Runner/Info.plist.
  static const googleIosClientId =
      '785025965315-e9dj46u9bk97322l99f3jdnbn7rq07gu.apps.googleusercontent.com';
  static const googleWebClientId =
      '785025965315-u1hqm7s7dndse7t6u9hcn0av44igael7.apps.googleusercontent.com';

  /// How long the app can stay in the background before it asks for Face ID again.
  static const lockAfter = Duration(seconds: 30);

  static String get ingestUrl => '$supabaseUrl/functions/v1/ingest';
}
