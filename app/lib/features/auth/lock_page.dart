import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/lock.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/icon_tile.dart';
import '../../ui/launch_skeleton.dart';
import '../../ui/tokens.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  @override
  void initState() {
    super.initState();
    // Prompt as soon as the lock screen appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    await ref
        .read(lockProvider.notifier)
        .unlock(AppLocalizations.of(context).unlockReason);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = ref.watch(lockProvider);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: LaunchSkeleton(
        child: Stack(
          children: [
            // A scrim over the grey blocks so the text and button are read against a calm background.
            Positioned.fill(
              child: ColoredBox(
                color: AppTokens.bg
                    .resolveFrom(context)
                    .withValues(alpha: 0.82),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.45),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            IconTile(
                              color: AppTokens.gold.resolveFrom(context),
                              icon: LucideIcons.lock,
                              iconSize: 21,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t.lockTitle,
                                style: TextStyle(
                                  color: AppTokens.text.resolveFrom(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.failed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            t.unlockFailed,
                            style: TextStyle(
                              color: AppTokens.muted.resolveFrom(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      PrimaryButton(
                        label: t.unlock,
                        onPressed: state.busy ? null : _unlock,
                      ),
                    ],
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
