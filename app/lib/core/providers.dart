import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import 'token_repository.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseProvider)),
);

final tokenRepositoryProvider = Provider<TokenRepository>(
  (ref) => SupabaseTokenRepository(ref.watch(supabaseProvider)),
);

/// Emits whenever the signed-in state changes. The router refreshes on it.
final signedInProvider = StreamProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).signedIn;
});

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override sharedPrefsProvider in main()'),
);

const _localeKey = 'locale';

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final saved = ref.read(sharedPrefsProvider).getString(_localeKey);
    return Locale(saved == 'ar' ? 'ar' : 'en');
  }

  Future<void> set(String languageCode) async {
    state = Locale(languageCode == 'ar' ? 'ar' : 'en');
    await ref
        .read(sharedPrefsProvider)
        .setString(_localeKey, state.languageCode);
  }
}
