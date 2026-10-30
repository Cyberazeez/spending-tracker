import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_repository.dart';
import '../../core/lock.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

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
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(_email.text, _password.text);
      // The password was just entered, so skip the Face ID prompt this once.
      ref.read(lockProvider.notifier).markUnlocked();
    } on SignInException catch (e) {
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(t.loginTitle)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 24),
            CupertinoTextField(
              controller: _email,
              placeholder: t.email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              padding: const EdgeInsets.all(14),
            ),
            if (missingEmail) _Error(t.fieldRequired),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _password,
              placeholder: t.password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              padding: const EdgeInsets.all(14),
            ),
            if (missingPassword) _Error(t.fieldRequired),
            if (_failure != null)
              _Error(
                _failure == SignInFailure.invalidCredentials
                    ? t.invalidCredentials
                    : t.networkError,
              ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : Text(t.signIn),
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.danger.resolveFrom(context),
        fontSize: 13,
      ),
    ),
  );
}
