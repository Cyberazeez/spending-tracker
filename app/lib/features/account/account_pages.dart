import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth_repository.dart';
import '../../core/capture_bridge.dart';
import '../../core/capture_setup.dart';
import '../../core/providers.dart';
import '../../core/widget_bridge.dart';
import '../../core/widget_setup.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/settings_group.dart';
import '../../ui/tokens.dart';

/// Bumped after a profile change so the screens that show the name or email redraw.
class AccountRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final accountRevisionProvider = NotifierProvider<AccountRevision, int>(
  AccountRevision.new,
);

const _minPasswordLength = 8;

/// More > Account: Profile, Security, Privacy.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    ref.watch(accountRevisionProvider);
    final auth = ref.read(authRepositoryProvider);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.accountTitle),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: LucideIcons.user,
                  color: const Color(0xFF6C8CFF),
                  title: t.accountProfile,
                  subtitle: auth.displayName ?? auth.email,
                  onTap: () => context.push(profilePath),
                ),
                SettingsRow(
                  icon: LucideIcons.shieldCheck,
                  color: const Color(0xFF3CC4A8),
                  title: t.accountSecurity,
                  subtitle: t.accountSecurityHint,
                  onTap: () => context.push(securityPath),
                ),
                SettingsRow(
                  icon: LucideIcons.eyeOff,
                  color: const Color(0xFFC084FC),
                  title: t.accountPrivacy,
                  onTap: () => context.push(privacyPath),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Name and email. The name is stored in the account's profile data; an email change is confirmed by a link
/// sent to the new address.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authRepositoryProvider);
    _name = TextEditingController(text: auth.displayName ?? '');
    _email = TextEditingController(text: auth.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final auth = ref.read(authRepositoryProvider);
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.length > 60) {
      setState(() => _error = t.accountNameTooLong);
      return;
    }
    final emailChanged =
        email.toLowerCase() != (auth.email ?? '').toLowerCase();
    if (emailChanged &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = t.accountEmailInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (name != (auth.displayName ?? '')) {
        await auth.updateName(name);
        ref.read(accountRevisionProvider.notifier).bump();
      }
      if (emailChanged) await auth.changeEmail(email);
      if (!mounted) return;
      if (emailChanged) {
        setState(() => _info = t.accountEmailSent);
      } else if (mounted) {
        popOrHome(context);
      }
    } catch (_) {
      if (mounted) setState(() => _error = t.accountSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.accountProfile),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) FormError(_error!),
            if (_info != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                child: Text(
                  _info!,
                  style: TextStyle(
                    color: AppTokens.muted.resolveFrom(context),
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            PrimaryButton(label: t.accountSave, busy: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// Change password. The current one is checked first. Afterwards the capture and widget tokens of this phone are
/// replaced (they were issued under the old password) and reconnect by themselves.
class SecurityPage extends ConsumerStatefulWidget {
  const SecurityPage({super.key});

  @override
  ConsumerState<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends ConsumerState<SecurityPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    if (_current.text.isEmpty) {
      setState(() => _error = t.fieldRequired);
      return;
    }
    if (_next.text.length < _minPasswordLength) {
      setState(() => _error = t.secTooShort);
      return;
    }
    if (_next.text != _again.text) {
      setState(() => _error = t.secMismatch);
      return;
    }
    if (_next.text == _current.text) {
      setState(() => _error = t.secSame);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    final tokens = ref.read(tokenRepositoryProvider);
    final capture = ref.read(captureBridgeProvider);
    final widget = ref.read(widgetBridgeProvider);
    try {
      await auth.changePassword(current: _current.text, next: _next.text);
    } on PasswordException catch (e) {
      if (mounted) {
        setState(
          () => _error = switch (e.failure) {
            PasswordFailure.wrongCurrent => t.secWrongCurrent,
            PasswordFailure.tooShort => t.secTooShort,
            PasswordFailure.network => t.networkError,
          },
        );
      }
      if (mounted) setState(() => _busy = false);
      return;
    }
    // The password is changed; replacing the phone's tokens is best effort and retried on the next app start.
    try {
      await releaseCapture(capture, tokens);
      await releaseWidget(widget, tokens);
      unawaited(ensureCaptureReady(capture, tokens, () => auth.userId));
      unawaited(ensureWidgetReady(widget, tokens, () => auth.userId));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(t.secDone),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.done),
          ),
        ],
      ),
    );
    if (mounted) popOrHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.accountSecurity),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppField(
              controller: _current,
              label: t.secCurrent,
              obscure: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 16),
            AppField(
              controller: _next,
              label: t.secNew,
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
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) FormError(_error!),
            const SizedBox(height: 24),
            PrimaryButton(
              label: t.secChangePassword,
              busy: _busy,
              onPressed: _save,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 4, right: 4),
              child: Text(
                t.secNote,
                style: TextStyle(
                  color: AppTokens.muted.resolveFrom(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder until the privacy options exist.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.accountPrivacy),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppCard(
              child: Text(
                t.privacyBody,
                style: TextStyle(
                  color: AppTokens.text.resolveFrom(context),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
