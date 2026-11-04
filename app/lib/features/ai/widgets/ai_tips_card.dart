import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router.dart';
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
      final saved = await ref.read(dataRepositoryProvider).savedAiTips(_month);
      if (mounted && _tips.isEmpty) setState(() => _tips = saved);
    } catch (_) {
      // Saved tips are a convenience; the button still works.
    }
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
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    const onHero = Color(0xFFFFFFFF);
    const softHero = Color(0xCCFFFFFF);
    final open = ref.read(routerProvider).push;

    Widget pill(String label, VoidCallback? onPressed, {Widget? leading}) =>
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: _busy && leading != null
                ? const CupertinoActivityIndicator(color: onHero)
                : Text(
                    label,
                    style: const TextStyle(
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusHero),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart.resolve(
                Directionality.of(context),
              ),
              end: AlignmentDirectional.bottomEnd.resolve(
                Directionality.of(context),
              ),
              colors: [
                AppTokens.heroFrom.resolveFrom(context),
                AppTokens.heroTo.resolveFrom(context),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.sparkles, size: 20, color: onHero),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.aiTipsTitle,
                        style: const TextStyle(
                          color: onHero,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
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
                    style: const TextStyle(color: softHero, fontSize: 14),
                  ),
                for (final tip in _tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 7),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: onHero,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 6, height: 6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              color: onHero,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFFFD6D4),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_tips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      t.aiTipsNote,
                      style: const TextStyle(color: softHero, fontSize: 12),
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
