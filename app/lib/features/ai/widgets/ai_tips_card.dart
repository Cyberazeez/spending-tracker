import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router.dart';
import '../../../ui/app_card.dart';
import '../../../ui/icon_tile.dart';
import '../../../ui/tokens.dart';
import '../../insights/metrics.dart';
import '../ai_aggregates.dart';
import '../ai_messages.dart';
import '../providers.dart';

/// Savings tips from Claude on the month's totals. Only shown while the AI switch in More is on.
class AiTipsCard extends ConsumerStatefulWidget {
  const AiTipsCard({
    super.key,
    required this.insights,
    required this.categories,
    required this.budgets,
    required this.today,
  });

  final Insights insights;
  final List<Category> categories;
  final List<Budget> budgets;
  final DateTime today;

  @override
  ConsumerState<AiTipsCard> createState() => _AiTipsCardState();
}

class _AiTipsCardState extends ConsumerState<AiTipsCard> {
  List<String> _tips = const [];
  String? _error;
  bool _busy = false;

  String get _month =>
      '${widget.today.year}-${widget.today.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await ref
          .read(dataRepositoryProvider)
          .savedAiTips(_month, language: ref.read(localeProvider).languageCode);
      if (mounted && _tips.isEmpty) setState(() => _tips = saved);
    } catch (_) {
      // Saved tips are a convenience; the button still works.
    }
  }

  /// The app language changed: show the saved tips in the new language, or write them again if there are none.
  Future<void> _languageChanged() async {
    final had = _tips.isNotEmpty;
    setState(() {
      _tips = const [];
      _error = null;
    });
    await _loadSaved();
    if (mounted && had && _tips.isEmpty && !_busy) await _ask();
  }

  Future<void> _ask() async {
    final agg = buildAiAggregates(
      widget.insights,
      widget.categories,
      widget.budgets,
      widget.today,
    );
    if (agg == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final lang = ref.read(localeProvider).languageCode;
    final out = await ref.read(dataRepositoryProvider).aiTips(agg, lang);
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = false;
      if (out.ok) {
        _tips = out.tips;
        _error = out.tips.isEmpty ? t.aiTipsNone : null;
      } else {
        _error = aiReasonText(t, out.reason);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(aiEnabledProvider).value != true) {
      return const SizedBox.shrink();
    }
    final t = AppLocalizations.of(context);
    ref.listen(localeProvider, (prev, next) {
      if (prev?.languageCode != next.languageCode) _languageChanged();
    });
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    // Ink on gold in both modes (white on gold was 1.6:1).
    final onHero = AppTokens.onTint.resolveFrom(context);
    final softHero = onHero;
    final open = ref.read(routerProvider).push;

    Widget pill(String label, VoidCallback? onPressed, {Widget? leading}) =>
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: onPressed,
          child: Container(
            margin: const EdgeInsets.only(right: 3, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: onHero, width: AppTokens.outline),
              boxShadow: [BoxShadow(color: onHero, offset: const Offset(3, 4))],
            ),
            child: _busy && leading != null
                ? CupertinoActivityIndicator(color: onHero)
                : Text(
                    label,
                    style: TextStyle(
                      color: onHero,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => open(aiChatPath),
        child: AppCard(
          color: AppTokens.gold.resolveFrom(context),
          radius: AppTokens.radiusHero,
          shadow: const Offset(5, 6),
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconTile(
                      color: Color(0xFFFFFFFF),
                      icon: LucideIcons.sparkles,
                      size: 38,
                      iconSize: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.aiTipsTitle,
                        style: TextStyle(
                          color: onHero,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      arabic
                          ? LucideIcons.chevronLeft
                          : LucideIcons.chevronRight,
                      size: 20,
                      color: softHero,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_tips.isEmpty && _error == null)
                  Text(
                    t.aiTipsEmpty,
                    style: TextStyle(
                      color: softHero,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                for (final tip in _tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: onHero,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(width: 6, height: 6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              color: onHero,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    // Ink with a warning sign: red text on gold does not reach 4.5:1.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.triangleAlert,
                          size: 16,
                          color: onHero,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: onHero,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_tips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      t.aiTipsNote,
                      style: TextStyle(
                        color: softHero,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    pill(
                      _tips.isEmpty ? t.aiTipsGet : t.aiTipsRefresh,
                      _busy ? null : _ask,
                      leading: const SizedBox.shrink(),
                    ),
                    pill(t.aiChatOpen, () => open(aiChatPath)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
