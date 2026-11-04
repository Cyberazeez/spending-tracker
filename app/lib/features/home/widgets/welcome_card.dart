import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router.dart';
import '../../../ui/app_card.dart';
import '../../../ui/tokens.dart';
import '../../account/account_providers.dart';
import '../../shell/tabs.dart';

/// The first steps of a new account: bank accounts, SMS capture, a monthly budget. Disappears by itself when all
/// three are done, or when the user taps Hide.
class WelcomeCard extends ConsumerWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(welcomeVisibleProvider)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final w = ref.watch(welcomeStateProvider);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);

    Widget step(bool done, String label, VoidCallback onTap) => Semantics(
      button: true,
      selected: done,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(
                done ? LucideIcons.circleCheck : LucideIcons.circle,
                size: 22,
                color: done ? accent : muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: done ? muted : text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Icon(CupertinoIcons.chevron_forward, size: 14, color: muted),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.welcomeTitle,
                    style: TextStyle(
                      color: text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () =>
                      ref.read(welcomeHiddenProvider.notifier).hide(),
                  child: Text(
                    t.welcomeHide,
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                ),
              ],
            ),
            Text(
              t.welcomeProgress(w.done.toString(), '3'),
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            step(w.accounts, t.welcomeAccounts, () => context.push(banksPath)),
            step(w.capture, t.welcomeCapture, () => context.push(capturePath)),
            step(
              w.budget,
              t.welcomeBudget,
              () => ref.read(tabControllerProvider).index = 3,
            ),
          ],
        ),
      ),
    );
  }
}
