import 'package:flutter/cupertino.dart';

import '../../../ui/chevron.dart';
import '../../insights/budget_flow.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router.dart';
import '../../../ui/app_card.dart';
import '../../../ui/tokens.dart';
import '../../account/account_providers.dart';
import '../../../ui/icon_tile.dart';

/// The first steps of a new account: bank accounts, SMS capture, a monthly budget. Disappears by itself when all
/// three are done, or when the user taps Hide.
class WelcomeCard extends ConsumerStatefulWidget {
  const WelcomeCard({super.key, this.showSteps = true});

  /// False on the empty Home of a new account: the card above it already offers the first step, so this one is
  /// only the title, the progress and Hide.
  final bool showSteps;

  @override
  ConsumerState<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends ConsumerState<WelcomeCard> {
  /// Compact card (empty Home): the steps show after the title is tapped.
  bool _open = false;

  bool get _steps => widget.showSteps || _open;

  @override
  void initState() {
    super.initState();
    // The card's lifetime starts the first time it is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(welcomeVisibleProvider)) {
        ref.read(welcomeProvider.notifier).markSeen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(welcomeVisibleProvider)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final w = ref.watch(welcomeStateProvider);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);

    final progress = t.welcomeProgress(
      w.done.toString(),
      WelcomeState.total.toString(),
    );
    // The card's head, folded or open: gold target tile, title and progress.
    Widget header() => Expanded(
      child: Row(
        children: [
          IconTile(
            color: AppTokens.gold.resolveFrom(context),
            icon: LucideIcons.target,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.welcomeTitle,
                  style: TextStyle(
                    color: text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  progress,
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (ref.watch(welcomeProvider).collapsed) {
      // Folded: one line that opens the card again.
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Semantics(
          button: true,
          label:
              '${t.welcomeTitle}, ${t.welcomeProgress(w.done.toString(), WelcomeState.total.toString())}',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(welcomeProvider.notifier).setCollapsed(false),
            child: AppCard(
              pressable: true,
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    header(),
                    Icon(CupertinoIcons.chevron_down, size: 16, color: muted),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

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
              ForwardChevron(size: 14, color: muted),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.showSteps)
                  header()
                else
                  Expanded(
                    child: Semantics(
                      button: true,
                      excludeSemantics: false,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _open = !_open),
                        child: Row(children: [header()]),
                      ),
                    ),
                  ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () =>
                      ref.read(welcomeProvider.notifier).setCollapsed(true),
                  child: Text(
                    t.welcomeHide,
                    style: TextStyle(
                      color: AppTokens.accentText.resolveFrom(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (_steps) const SizedBox(height: 8),
            if (_steps)
              step(
                w.capture,
                t.welcomeCapture,
                () => context.push(capturePath),
              ),
            if (_steps)
              step(
                w.budget,
                t.welcomeBudget,
                () => showMonthlyBudgetFlow(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}
