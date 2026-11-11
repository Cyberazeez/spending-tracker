import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_repository.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/tokens.dart';

/// "Forgot password?": asks for the email and sends the reset link. The answer is the same whether or not the address
/// has an account, so the screen cannot be used to find out who is registered.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  static const cooldownSeconds = 60;

  final _email = TextEditingController();
  bool _busy = false;
  bool _submitted = false;
  bool _sent = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _wait = cooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _submitted = true;
      _error = null;
    });
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@') || _wait > 0) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) setState(() => _sent = true);
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
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final email = _email.text.trim();
    final invalid = _submitted && (email.isEmpty || !email.contains('@'));
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.forgotTitle),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(t.forgotIntro, style: TextStyle(color: muted, fontSize: 15)),
            const SizedBox(height: 20),
            AppField(
              controller: _email,
              placeholder: t.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autofocus: true,
              onSubmitted: (_) => _send(),
            ),
            if (invalid) FormError(t.accountEmailInvalid),
            if (_error != null) FormError(_error!),
            if (_sent)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  t.forgotSent,
                  key: const ValueKey('forgot-sent'),
                  style: TextStyle(
                    color: AppTokens.accentText.resolveFrom(context),
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _wait > 0 ? t.forgotWait(_wait) : t.forgotSend,
              busy: _busy,
              onPressed: _wait > 0 ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
