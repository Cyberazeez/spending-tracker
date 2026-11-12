import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/lock.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/icon_tile.dart';
import '../../ui/halala_logo.dart';
import '../../ui/tokens.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

/// How long the lock screen waits before asking for Face ID, so the logo's coin drop is seen first (the system
/// prompt would cover it, and a quick unlock would skip the screen altogether). No wait with Reduce Motion.
const lockPromptDelay = Duration(milliseconds: 900);

class _LockPageState extends ConsumerState<LockPage> {
  Timer? _wait;
  bool _promptWhenBack = false;

  // The automatic prompt only runs while the app is in front: iOS refuses Face ID in the background and that would
  // show "Unlock failed". Left within the wait, it asks when the app comes back.
  late final AppLifecycleListener _life = AppLifecycleListener(
    onResume: () {
      if (_promptWhenBack) {
        _promptWhenBack = false;
        _unlock();
      }
    },
  );

  void _autoPrompt() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) {
      _promptWhenBack = true;
      return;
    }
    _unlock();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _life; // start listening
      if (MediaQuery.disableAnimationsOf(context)) {
        _autoPrompt();
      } else {
        _wait = Timer(lockPromptDelay, _autoPrompt);
      }
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _life.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    _wait?.cancel(); // Unlock tapped before the automatic prompt: ask once
    _promptWhenBack = false;
    if (!mounted) return;
    await ref
        .read(lockProvider.notifier)
        .unlock(AppLocalizations.of(context).unlockReason);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = ref.watch(lockProvider);
    final text = AppTokens.text.resolveFrom(context);
    // Only the logo, the lock title and Unlock on the page colour (the same colour and logo as the iOS launch
    // screen, so opening the app goes straight from one to the other).
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HalalaLogo(width: 220, dropCoins: true),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTile(
                      color: AppTokens.gold.resolveFrom(context),
                      icon: LucideIcons.lock,
                      iconSize: 21,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        t.lockTitle,
                        style: TextStyle(
                          color: text,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      t.unlockFailed,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTokens.muted.resolveFrom(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: t.unlock,
                  onPressed: state.busy ? null : _unlock,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
