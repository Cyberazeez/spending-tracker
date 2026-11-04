import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_repository.dart';
import '../../core/capture_bridge.dart';
import '../../core/capture_setup.dart';
import '../../core/lock.dart';
import '../../core/reminder_bridge.dart';
import '../../core/widget_setup.dart';
import '../../core/providers.dart';
import '../../core/widget_bridge.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/tokens.dart';

/// Account > Privacy > Delete my account. Needs the password again and a typed confirmation word. The server checks
/// the password too, deletes the account and, through the database cascade, every row of it.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _word = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _word.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    if (_word.text.trim().toUpperCase() != t.deleteWord.toUpperCase()) {
      setState(() => _error = t.deleteWordMismatch(t.deleteWord));
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = t.fieldRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    final capture = ref.read(captureBridgeProvider);
    final widget = ref.read(widgetBridgeProvider);
    final lock = ref.read(lockProvider.notifier);
    final tokens = ref.read(tokenRepositoryProvider);
    final reminders = ref.read(reminderBridgeProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final uid = auth.userId;
    try {
      await auth.deleteAccount(_password.text);
    } on DeleteAccountException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = switch (e.failure) {
            DeleteFailure.wrongPassword => t.deleteWrongPassword,
            DeleteFailure.tooMany => t.deleteTooMany,
            DeleteFailure.network => t.deleteFailed,
          };
        });
      }
      return;
    }
    // The account is gone. Wipe what this phone kept for it (the tokens died with the account, revoking them just
    // fails quietly): credentials, the offline queue, the widget numbers and the scheduled bill reminders. The
    // sign-out already happened, so the router returns to the login screen by itself.
    try {
      await releaseCapture(capture, tokens);
      await releaseWidget(widget, tokens);
      await reminders.clear();
      await prefs.remove('welcome_hidden_$uid');
      await prefs.setBool('reminders_on', false);
    } catch (_) {}
    lock.lockNow();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final danger = AppTokens.danger.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.deleteTitle),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppCard(
              child: Text(
                t.deleteWarn,
                style: TextStyle(
                  color: AppTokens.text.resolveFrom(context),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            AppField(
              controller: _word,
              label: t.deleteTypeWord(t.deleteWord),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppField(
              controller: _password,
              label: t.deletePassword,
              obscure: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _delete(),
            ),
            if (_error != null) FormError(_error!),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: t.deleteButton,
              excludeSemantics: true,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 52),
                onPressed: _busy ? null : _delete,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: danger,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Center(
                      child: _busy
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : Text(
                              t.deleteButton,
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
