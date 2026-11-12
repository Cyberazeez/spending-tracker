import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_repository.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/tokens.dart';

/// Shown after the person opens the emailed reset link. They hold a session only to choose a new password; the router
/// keeps them here until it is set.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    if (_next.text.length < 8) {
      setState(() => _error = t.secTooShort);
      return;
    }
    if (_next.text != _again.text) {
      setState(() => _error = t.secMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).setNewPassword(_next.text);
      // The router leaves the reset screen as soon as this flag clears.
      ref.read(recoveryPendingProvider.notifier).set(false);
    } on PasswordException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.failure == PasswordFailure.tooShort
              ? t.signUpWeak
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
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
          children: [
            Text(
              t.resetTitle,
              style: TextStyle(
                color: AppTokens.text.resolveFrom(context),
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(t.secRulesHint, style: TextStyle(color: muted, fontSize: 15)),
            const SizedBox(height: 24),
            AppField(
              controller: _next,
              placeholder: t.secNew,
              obscure: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              autofocus: true,
            ),
            const SizedBox(height: 12),
            AppField(
              controller: _again,
              placeholder: t.secConfirm,
              obscure: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) FormError(_error!),
            const SizedBox(height: 24),
            PrimaryButton(label: t.resetSave, busy: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
