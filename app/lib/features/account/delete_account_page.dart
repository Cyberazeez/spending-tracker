import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/settings_group.dart' show dangerTileColor;
import '../../ui/swipe_action.dart' show swipeLabelColor;
import '../../ui/confirm_sheet.dart';

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
import '../../ui/press.dart';

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
    final usesPassword = ref.read(authRepositoryProvider).hasPassword;
    if (usesPassword && _password.text.isEmpty) {
      setState(() => _error = t.fieldRequired);
      return;
    }
    final sure = await showConfirmSheet(
      context,
      title: t.deleteSureTitle,
      message: t.deleteSureBody,
      confirmLabel: t.deleteSureConfirm,
      cancelLabel: t.deleteKeep,
      destructive: true,
      icon: LucideIcons.triangleAlert,
      iconColor: dangerTileColor,
      cancelPrimary: true,
    );
    if (sure != true || !mounted) return;
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
      if (usesPassword) {
        await auth.deleteAccount(_password.text);
      } else {
        // No password: Apple's sheet proves it is the owner, and the server checks the proof is for this account.
        final proof = await auth.proveWithApple();
        if (proof == null) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        await auth.deleteAccountWithApple(proof);
      }
    } on SocialSignInException {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = t.appleFailed;
        });
      }
      return;
    } on DeleteAccountException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = switch (e.failure) {
            DeleteFailure.wrongPassword => t.deleteWrongPassword,
            DeleteFailure.wrongApple => t.deleteWrongApple,
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
      await prefs.remove('welcome_collapsed_$uid');
      await prefs.remove('welcome_first_$uid');
      await prefs.setBool('reminders_on', false);
    } catch (_) {}
    lock.lockNow();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final danger = AppTokens.danger.resolveFrom(context);
    final onDanger = swipeLabelColor(danger);
    final ink = AppTokens.onTint.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.deleteTitle),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppCard(
              key: const ValueKey('delete-warning'),
              color: dangerTileColor,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.triangleAlert, size: 22, color: ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.deleteWarn,
                      style: TextStyle(
                        color: ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppField(
              controller: _word,
              label: t.deleteTypeWord(t.deleteWord),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            if (ref.watch(authRepositoryProvider).hasPassword)
              AppField(
                controller: _password,
                label: t.deletePassword,
                obscure: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _delete(),
              )
            else
              Text(
                t.deleteApple,
                style: TextStyle(
                  color: AppTokens.muted.resolveFrom(context),
                  fontSize: 14,
                  height: 1.4,
                ),
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
                pressedOpacity: 1,
                onPressed: _busy ? null : _delete,
                child: Padding(
                  padding: const EdgeInsets.only(right: 3, bottom: 4),
                  child: Pressable(
                    offset: const Offset(3, 4),
                    enabled: !_busy,
                    builder: (context, depth) => DecoratedBox(
                      key: const ValueKey('delete-button'),
                      decoration: BoxDecoration(
                        color: danger,
                        borderRadius: BorderRadius.circular(26),
                        border: outlineOf(context),
                        boxShadow: _busy
                            ? null
                            : hardShadowOf(
                                context,
                                offset: const Offset(3, 4) * (1 - depth),
                              ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: Center(
                          child: _busy
                              ? CupertinoActivityIndicator(color: onDanger)
                              : Text(
                                  t.deleteButton,
                                  style: TextStyle(
                                    color: onDanger,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
