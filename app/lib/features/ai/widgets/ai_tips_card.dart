import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/app_card.dart';
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
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, size: 20, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.aiTipsTitle,
                    style: TextStyle(
                      color: text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_tips.isEmpty && _error == null)
              Text(t.aiTipsEmpty, style: TextStyle(color: muted, fontSize: 14)),
            for (final tip in _tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 6, height: 6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(color: text, fontSize: 15),
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
                  style: TextStyle(
                    color: AppTokens.danger.resolveFrom(context),
                    fontSize: 14,
                  ),
                ),
              ),
            if (_tips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  t.aiTipsNote,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: _busy ? null : _ask,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : Text(
                      _tips.isEmpty ? t.aiTipsGet : t.aiTipsRefresh,
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
