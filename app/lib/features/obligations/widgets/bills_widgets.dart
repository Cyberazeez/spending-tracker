import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/app_card.dart';
import '../../../ui/icon_tile.dart';
import '../../../ui/sliding_pill.dart';
import '../../../ui/swipe_action.dart';
import '../../../ui/tokens.dart';

/// Pill-style segmented control (Upcoming / Overdue / History).
class PillSegments<T> extends StatelessWidget {
  const PillSegments({
    super.key,
    required this.value,
    required this.labels,
    required this.onChanged,
    this.badges = const {},
  });

  final T value;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;

  /// A small red count next to a label (unpaid items from earlier months, for instance).
  final Map<T, int> badges;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.card.resolveFrom(context),
        borderRadius: BorderRadius.circular(26),
        border: outlineOf(context),
        boxShadow: hardShadowOf(context, offset: const Offset(3, 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            // The emerald pill slides to the chosen segment.
            SlidingPill(
              count: labels.length,
              index: labels.keys.toList().indexOf(value),
              pill: DecoratedBox(
                key: const ValueKey('segment-pill'),
                decoration: BoxDecoration(
                  color: AppTokens.accent.resolveFrom(context),
                  borderRadius: BorderRadius.circular(22),
                  border: outlineOf(context, width: AppTokens.outlineThin),
                ),
              ),
            ),
            Row(
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
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      e.value,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: e.key == value
                                            ? AppTokens.onAccent.resolveFrom(
                                                context,
                                              )
                                            : AppTokens.muted.resolveFrom(
                                                context,
                                              ),
                                      ),
                                    ),
                                  ),
                                  if ((badges[e.key] ?? 0) > 0) ...[
                                    const SizedBox(width: 6),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppTokens.danger.resolveFrom(
                                          context,
                                        ),
                                        borderRadius: BorderRadius.circular(9),
                                        border: outlineOf(
                                          context,
                                          width: AppTokens.outlineThin,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        child: Text(
                                          '${badges[e.key]}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: onDanger(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    // The shadow stays inside the widget's own box (like AppCard).
    return Padding(
      padding: const EdgeInsets.only(right: 3, bottom: 4),
      child: box,
    );
  }
}

/// Icon, colour and tile for each obligation kind.
({IconData icon, Color color}) kindStyle(String kind) => switch (kind) {
  'bill' => (icon: LucideIcons.receipt, color: const Color(0xFFFFA574)),
  'loan' => (icon: LucideIcons.landmark, color: const Color(0xFF9CC4FF)),
  _ => (icon: LucideIcons.repeat, color: const Color(0xFFCDB4FF)),
};

/// Text on a [AppTokens.danger] fill: white on the deep light-mode red, ink on the light dark-mode pink.
Color onDanger(BuildContext context) =>
    swipeLabelColor(AppTokens.danger.resolveFrom(context));

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
        AppTokens.onTint.resolveFrom(context),
      ),
      PillTone.danger => (
        AppTokens.danger.resolveFrom(context),
        onDanger(context),
      ),
      PillTone.muted => (
        AppTokens.card.resolveFrom(context),
        AppTokens.muted.resolveFrom(context),
      ),
    };
    // A word in an outlined pill: the status is never told by colour alone.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: outlineOf(context, width: AppTokens.outlineThin),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
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
                IconTile(color: s.color, icon: s.icon, iconSize: 21),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!stacked) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: StatusPill(label: statusLabel, tone: tone),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section of rows inside one outlined card, 2 pt lines between rows.
class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = AppTokens.bar.resolveFrom(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Container(height: 2, color: line),
            children[i],
          ],
        ],
      ),
    );
  }
}
