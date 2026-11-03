import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/tokens.dart';

/// Pill-style segmented control (Upcoming / Overdue / History).
class PillSegments<T> extends StatelessWidget {
  const PillSegments({
    super.key,
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.card.resolveFrom(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final e in labels.entries)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: e.key == value,
                  excludeSemantics: true,
                  label: e.value,
                  onTap: () => onChanged(e.key),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(e.key),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: e.key == value
                              ? AppTokens.accent.resolveFrom(context)
                              : null,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            child: Text(
                              e.value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: e.key == value
                                    ? AppTokens.onAccent.resolveFrom(context)
                                    : AppTokens.muted.resolveFrom(context),
                              ),
                            ),
                          ),
                        ),
                      ),
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

/// Icon, colour and tile for each obligation kind.
({IconData icon, Color color}) kindStyle(String kind) => switch (kind) {
  'bill' => (icon: LucideIcons.receipt, color: const Color(0xFFFFB340)),
  'card_statement' => (
    icon: LucideIcons.creditCard,
    color: const Color(0xFFFF8A3D),
  ),
  'loan' => (icon: LucideIcons.landmark, color: const Color(0xFF6B8CFF)),
  _ => (icon: LucideIcons.repeat, color: const Color(0xFF3CC4A8)),
};

enum PillTone { ok, warn, danger, muted }

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.ok => (
        AppTokens.okBg.resolveFrom(context),
        AppTokens.okText.resolveFrom(context),
      ),
      PillTone.warn => (
        AppTokens.warnBg.resolveFrom(context),
        AppTokens.warnText.resolveFrom(context),
      ),
      PillTone.danger => (
        AppTokens.danger.resolveFrom(context).withValues(alpha: 0.16),
        AppTokens.danger.resolveFrom(context),
      ),
      PillTone.muted => (
        AppTokens.bar.resolveFrom(context),
        AppTokens.muted.resolveFrom(context),
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// One obligation: kind tile, name + detail line, status pill and amount.
class ObligationRow extends StatelessWidget {
  const ObligationRow({
    super.key,
    required this.name,
    required this.detail,
    required this.kind,
    required this.statusLabel,
    required this.tone,
    required this.onTap,
  });

  final String name;
  final String detail;
  final String kind;
  final String statusLabel;
  final PillTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = kindStyle(kind);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(s.icon, size: 20, color: s.color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: text,
                        ),
                      ),
                      if (stacked) ...[
                        const SizedBox(height: 4),
                        StatusPill(label: statusLabel, tone: tone),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                ),
                if (!stacked) ...[
                  const SizedBox(width: 8),
                  StatusPill(label: statusLabel, tone: tone),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section of rows inside one card, hairline dividers between rows.
class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = AppTokens.bar.resolveFrom(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.card.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Container(height: 1, color: line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
