import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/app_card.dart';
import '../../../ui/tokens.dart';
import '../../insights/providers.dart';
import '../../transactions/providers.dart';
import '../ai_messages.dart';
import '../providers.dart';

/// Offers to let Claude pick categories for merchants that have none. Shown only while the AI switch is on and
/// at least one transaction is uncategorised.
class SuggestCategoriesCard extends ConsumerStatefulWidget {
  const SuggestCategoriesCard({super.key, required this.uncategorized});

  final int uncategorized;

  @override
  ConsumerState<SuggestCategoriesCard> createState() =>
      _SuggestCategoriesCardState();
}

class _SuggestCategoriesCardState extends ConsumerState<SuggestCategoriesCard> {
  bool _busy = false;
  String? _message;
  bool _failed = false;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final out = await ref.read(dataRepositoryProvider).suggestCategories();
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    if (out.ok) {
      ref.invalidate(transactionsProvider);
      ref.invalidate(categoriesProvider);
      // Insights, budget alerts and the Home cards are built from the same history.
      ref.invalidate(insightsProvider);
      ref.invalidate(budgetsProvider);
    }
    setState(() {
      _busy = false;
      _failed = !out.ok;
      _message = !out.ok
          ? aiReasonText(t, out.reason)
          : out.updated == 0
          ? t.aiSuggestNone
          : t.aiSuggestDone(out.updated.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(aiEnabledProvider).value == true;
    if (!enabled || (widget.uncategorized == 0 && _message == null)) {
      return const SizedBox.shrink();
    }
    final t = AppLocalizations.of(context);
    final accent = AppTokens.accent.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, size: 20, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.uncategorized == 0
                        ? (_message ?? '')
                        : t.aiSuggestTitle(widget.uncategorized.toString()),
                    style: TextStyle(
                      color: AppTokens.text.resolveFrom(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (_message != null && widget.uncategorized > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _message!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _failed
                        ? AppTokens.danger.resolveFrom(context)
                        : AppTokens.muted.resolveFrom(context),
                  ),
                ),
              ),
            if (widget.uncategorized > 0)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: _busy ? null : _run,
                child: _busy
                    ? const CupertinoActivityIndicator()
                    : Text(
                        t.aiSuggestAction,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
