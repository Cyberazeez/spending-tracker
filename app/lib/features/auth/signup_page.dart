import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_repository.dart';
import '../../core/lock.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
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
  String? _error;
  bool _checkEmail = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
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
          .signUp(name: name, email: email, password: _password.text);
      if (result == SignUpResult.confirmEmail) {
        lock.lockNow();
        if (mounted) setState(() => _checkEmail = true);
      }
      // signedIn: the session change moves the app to Home by itself.
    } on SignUpException catch (e) {
      lock.lockNow();
      if (mounted) {
        setState(
          () => _error = switch (e.failure) {
            SignUpFailure.emailTaken => t.signUpEmailTaken,
            SignUpFailure.weakPassword => t.secTooShort,
            SignUpFailure.invalidEmail => t.accountEmailInvalid,
            SignUpFailure.disabled => t.signUpDisabled,
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_checkEmail)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  t.signUpCheckEmail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTokens.text.resolveFrom(context),
                    fontSize: 17,
                    height: 1.4,
                  ),
                ),
              )
            else ...[
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
                    fontSize: 12,
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
              if (_error != null) FormError(_error!),
              const SizedBox(height: 24),
              PrimaryButton(
                label: t.signUpTitle,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
