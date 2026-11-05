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

  /// How long the app can stay in the background before it asks for Face ID again.
  static const lockAfter = Duration(seconds: 30);

  static String get ingestUrl => '$supabaseUrl/functions/v1/ingest';
}
