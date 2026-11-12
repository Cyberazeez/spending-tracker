import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_repository.dart';
import '../../core/legal.dart';
import '../../core/lock.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/app_form.dart';
import 'apple_button.dart';
import '../../ui/tokens.dart';

/// Create an account (closed family test: open sign-up, no invite code).
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  bool _agreed = false;
  String? _error;
  bool _checkEmail = false;
  String _sentTo = '';
  int _wait = 0;
  Timer? _timer;

  void _startCooldown() {
    setState(() => _wait = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (_busy || _wait > 0) return;
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(_sentTo);
      _startCooldown();
    } on ResetException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.failure == ResetFailure.tryLater
              ? t.forgotTryLater
              : t.networkError,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_agreed) return;
    final t = AppLocalizations.of(context);
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || name.length > 60) {
      setState(() => _error = t.signUpNameRequired);
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = t.accountEmailInvalid);
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = t.secTooShort);
      return;
    }
    if (_password.text != _again.text) {
      setState(() => _error = t.secMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // The password was just typed: skip the Face ID prompt this once (same as signing in).
    final lock = ref.read(lockProvider.notifier)..markUnlocked();
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .signUp(
            name: name,
            email: email,
            password: _password.text,
            termsVersion: legalVersion,
          );
      if (result == SignUpResult.confirmEmail) {
        lock.lockNow();
        if (mounted) {
          setState(() {
            _checkEmail = true;
            _sentTo = email;
          });
          _startCooldown();
        }
      }
      // signedIn: the session change moves the app to Home by itself.
    } on SignUpException catch (e) {
      lock.lockNow();
      if (mounted) {
        setState(
          () => _error = switch (e.failure) {
            SignUpFailure.emailTaken => t.signUpEmailTaken,
            SignUpFailure.weakPassword => t.signUpWeak,
            SignUpFailure.invalidEmail => t.accountEmailInvalid,
            SignUpFailure.disabled => t.signUpDisabled,
            SignUpFailure.tryLater => t.signUpTryLater,
            SignUpFailure.network => t.networkError,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.signUpTitle),
      child: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (_checkEmail) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  child: Text(
                    t.signUpCheckEmailTo(_sentTo),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTokens.text.resolveFrom(context),
                      fontSize: 17,
                      height: 1.4,
                    ),
                  ),
                ),
                if (_error != null) FormError(_error!),
                PrimaryButton(
                  label: _wait > 0 ? t.forgotWait(_wait) : t.signUpResend,
                  busy: _busy,
                  onPressed: _wait > 0 ? null : _resend,
                ),
                CupertinoButton(
                  onPressed: () => popOrHome(context),
                  child: Text(
                    t.signUpBackToSignIn,
                    style: TextStyle(
                      color: AppTokens.accentText.resolveFrom(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else ...[
                AppField(
                  controller: _name,
                  label: t.accountName,
                  placeholder: t.accountNameHint,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: 16),
                AppField(
                  controller: _email,
                  label: t.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 16),
                AppField(
                  controller: _password,
                  label: t.password,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    t.secRulesHint,
                    style: TextStyle(
                      color: AppTokens.muted.resolveFrom(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppField(
                  controller: _again,
                  label: t.secConfirm,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                _AgreeRow(
                  agreed: _agreed,
                  onChanged: (v) => setState(() => _agreed = v),
                ),
                if (_error != null) FormError(_error!),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: t.signUpTitle,
                  busy: _busy,
                  onPressed: _agreed ? _submit : null,
                ),
                if (!_agreed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.signUpAgreeRequired,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTokens.muted.resolveFrom(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                AppleSignInSection(enabled: _agreed),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The box a person ticks to agree to the Terms of Use and the Privacy Policy before an account is created.
class _AgreeRow extends ConsumerWidget {
  const _AgreeRow({required this.agreed, required this.onChanged});

  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = TextStyle(
      color: AppTokens.text.resolveFrom(context),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    Widget link(String label, LegalPage page) => CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 28),
      onPressed: () => ref.read(urlOpenerProvider).open(legalUri(page, locale)),
      child: Text(
        label,
        style: TextStyle(
          color: AppTokens.accentText.resolveFrom(context),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: t.signUpAgreePrefix,
          // Drawn larger than the native 14 pt box, like the mockup's 24 pt one.
          child: Transform.scale(
            scale: 1.4,
            child: CupertinoCheckbox(
              value: agreed,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppTokens.accent.resolveFrom(context),
              checkColor: AppTokens.onAccent.resolveFrom(context),
              side: BorderSide(
                color: AppTokens.line.resolveFrom(context),
                width: AppTokens.outlineThin,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(t.signUpAgreePrefix, style: text),
                link(t.legalTermsOfUse, LegalPage.terms),
                Text(t.signUpAgreeAnd, style: text),
                link(t.legalPrivacyPolicy, LegalPage.privacy),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
