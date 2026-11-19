import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router.dart';
import '../../../ui/app_card.dart';
import '../../../ui/chevron.dart';
import '../../../ui/icon_tile.dart';
import '../../../ui/tokens.dart';
import '../providers.dart';

/// One "Get tips" row on Insights (owner's design 2026-11-19). It opens the AI chat with the month's tips as the
/// first answer. Only shown while the AI switch in More is on.
class AiTipsRow extends ConsumerWidget {
  const AiTipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(aiEnabledProvider).value != true) {
      return const SizedBox.shrink();
    }
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        button: true,
        child: GestureDetector(
          key: const ValueKey('ai-tips-row'),
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(routerProvider).push(aiTipsChatPath),
          child: AppCard(
            child: Row(
              children: [
                IconTile(
                  color: AppTokens.gold.resolveFrom(context),
                  icon: LucideIcons.sparkles,
                  size: 40,
                  iconSize: 20,
                  outline: AppTokens.onTint.resolveFrom(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.aiTipsGet,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.text.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.aiTipsRowHint,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTokens.muted.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const ForwardChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
