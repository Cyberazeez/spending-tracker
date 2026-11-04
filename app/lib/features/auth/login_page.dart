import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../account/account_providers.dart';
import '../../core/auth_repository.dart';
import '../../core/lock.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../ui/app_form.dart';
import '../../ui/tokens.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _submitted = false;
  SignInFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _failure = null;
    });
    if (_email.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() => _busy = true);
    // The password is being entered now, so skip the Face ID prompt this once. Done before
    // signing in so the redirect that follows the session never lands on the lock screen.
    final lock = ref.read(lockProvider.notifier)..markUnlocked();
    // Kept before the await: the session redirect may remove this page before sign-in returns.
    final reactivated = ref.read(accountReactivatedProvider.notifier);
    try {
      final cancelled = await ref
          .read(authRepositoryProvider)
          .signIn(_email.text, _password.text);
      if (cancelled) reactivated.set(true);
      TextInput.finishAutofillContext();
    } on SignInException catch (e) {
      lock.lockNow();
      if (mounted) setState(() => _failure = e.failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final missingEmail = _submitted && _email.text.trim().isEmpty;
    final missingPassword = _submitted && _password.text.isEmpty;
    final accent = AppTokens.accent.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            children: [
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Icon(LucideIcons.wallet, size: 34, color: accent),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  t.loginTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTokens.text.resolveFrom(context),
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              AppField(
                controller: _email,
                placeholder: t.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
              ),
              if (missingEmail) FormError(t.fieldRequired),
              const SizedBox(height: 12),
              AppField(
                controller: _password,
                placeholder: t.password,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
              if (missingPassword) FormError(t.fieldRequired),
              if (_failure != null)
                FormError(
                  _failure == SignInFailure.invalidCredentials
                      ? t.invalidCredentials
                      : t.networkError,
                ),
              const SizedBox(height: 24),
              PrimaryButton(label: t.signIn, busy: _busy, onPressed: _submit),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: () => context.push(signUpPath),
                child: Text(
                  t.signUpLink,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
