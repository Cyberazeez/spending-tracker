import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/auth_repository.dart';
import '../../core/lock.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/tokens.dart';
import '../account/account_providers.dart';
import 'google_button.dart';

/// "or" divider with the Sign in with Apple and Sign in with Google buttons, shown on Sign in and Sign up. Each button
/// is hidden where its sign-in is not available, the divider when neither is. Closing either sheet is not an error.
class AppleSignInSection extends ConsumerStatefulWidget {
  const AppleSignInSection({super.key, this.enabled = true});

  /// False on Sign up until the Terms box is ticked (both buttons create an account too).
  final bool enabled;

  @override
  ConsumerState<AppleSignInSection> createState() => _AppleSignInSectionState();
}

class _AppleSignInSectionState extends ConsumerState<AppleSignInSection> {
  bool _busy = false;
  String? _error;

  Future<void> _run(SocialProvider provider) async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    // Apple's or Google's sheet is the proof of identity, so skip the Face ID prompt this once (same as typing a
    // password).
    final lock = ref.read(lockProvider.notifier)..markUnlocked();
    final reactivated = ref.read(accountReactivatedProvider.notifier);
    try {
      final auth = ref.read(authRepositoryProvider);
      final result = provider == SocialProvider.google
          ? await auth.signInWithGoogle()
          : await auth.signInWithApple();
      if (result == SocialResult.cancelled) lock.lockNow();
      if (result == SocialResult.reactivated) reactivated.set(true);
    } on SocialSignInException catch (e) {
      lock.lockNow();
      if (mounted) {
        setState(
          () => _error = e.failure == SocialFailure.network
              ? t.networkError
              : provider == SocialProvider.google
              ? t.googleFailed
              : t.appleFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRepositoryProvider);
    final apple = auth.appleSignInSupported;
    final google = auth.googleSignInSupported;
    if (!apple && !google) return const SizedBox.shrink();
    final off = _busy || !widget.enabled;
    final t = AppLocalizations.of(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 2,
                color: AppTokens.bar.resolveFrom(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                t.orDivider,
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                color: AppTokens.bar.resolveFrom(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (apple)
          Opacity(
            opacity: off ? 0.5 : 1,
            child: SignInWithAppleButton(
              onPressed: off ? null : () => _run(SocialProvider.apple),
              text: t.appleSignIn,
              height: 52,
              borderRadius: BorderRadius.circular(26),
              style: dark
                  ? SignInWithAppleButtonStyle.white
                  : SignInWithAppleButtonStyle.black,
            ),
          ),
        if (apple && google) const SizedBox(height: 12),
        if (google)
          Opacity(
            opacity: off ? 0.5 : 1,
            child: GoogleSignInButton(
              label: t.googleSignIn,
              onPressed: off ? null : () => _run(SocialProvider.google),
            ),
          ),
        if (_error != null) FormError(_error!),
      ],
    );
  }
}
