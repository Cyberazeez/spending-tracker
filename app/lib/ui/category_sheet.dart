import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/models.dart';
import '../features/home/category_groups.dart';
import '../features/home/group_style.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'tokens.dart';

IconData categoryIcon(Category c) => categoryIconByName(c.name);

/// A category's own icon by its name; names without one fall back to their group's icon.
IconData categoryIconByName(String name) => switch (name) {
  'Groceries' => LucideIcons.shoppingCart,
  'Dining' => LucideIcons.utensils,
  'Coffee' => LucideIcons.coffee,
  'Fuel' => LucideIcons.fuel,
  'Utilities' => LucideIcons.zap,
  'House Card' => LucideIcons.creditCard,
  'Entertainment' => LucideIcons.film,
  'Travel' => LucideIcons.plane,
  'Hotel' => LucideIcons.hotel,
  'Education' => LucideIcons.graduationCap,
  'Family & Kids' => LucideIcons.baby,
  'Gifts & Charity' => LucideIcons.gift,
  'Pets' => LucideIcons.pawPrint,
  'Personal care' => LucideIcons.scissors,
  'Insurance' => LucideIcons.shieldCheck,
  'Government & fees' => LucideIcons.landmark,
  'Fees' => LucideIcons.receipt,
  'Transfers' => LucideIcons.arrowLeftRight,
  'Income' => LucideIcons.banknote,
  _ => groupIcon(groupOf(name)),
};

/// The category picker: a bottom sheet with search, an optional row of suggestions and the categories as tiles
/// grouped like Home. Returns the category id, `''` when the "remove" button is tapped, or null when dismissed.
Future<String?> showCategorySheet(
  BuildContext context, {
  required List<Category> cats,
  required bool arabic,
  String? selectedId,
  String? subtitle,
  List<String> suggestedIds = const [],
  String? removeLabel,
  bool removeIsDestructive = true,
  String? title,
}) {
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => _CategorySheet(
      cats: cats,
      arabic: arabic,
      selectedId: selectedId,
      subtitle: subtitle,
      suggestedIds: suggestedIds,
      removeLabel: removeLabel,
      removeIsDestructive: removeIsDestructive,
      title: title,
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.cats,
    required this.arabic,
    required this.selectedId,
    required this.subtitle,
    required this.suggestedIds,
    required this.removeLabel,
    required this.removeIsDestructive,
    required this.title,
  });
  final List<Category> cats;
  final bool arabic;
  final String? selectedId;
  final String? subtitle;
  final List<String> suggestedIds;
  final String? removeLabel;
  final bool removeIsDestructive;
  final String? title;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Category c, String q) =>
      c.name.toLowerCase().contains(q) || (c.nameAr ?? '').contains(q);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bg = AppTokens.bg.resolveFrom(context);
    final card = AppTokens.card.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final bar = AppTokens.bar.resolveFrom(context);
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(13) / 13;
    final q = _search.text.trim().toLowerCase();
    final shown = [
      for (final c in widget.cats)
        if (q.isEmpty || _matches(c, q)) c,
    ];
    final byGroup = <CategoryGroup, List<Category>>{};
    for (final c in shown) {
      byGroup.putIfAbsent(groupOf(c.name), () => []).add(c);
    }
    final suggested = q.isEmpty
        ? [
            for (final id in widget.suggestedIds)
              ...widget.cats.where((c) => c.id == id),
          ]
        : const <Category>[];

    Widget heading(String s) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
        child: Text(
          s,
          style: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );

    SliverPadding grid(List<Category> list) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 76 + 2 * 13 * 1.25 * scale,
        ),
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final c = list[i];
          return _Tile(
            category: c,
            label: c.label(arabic: widget.arabic),
            selected: c.id == widget.selectedId,
            onTap: () => Navigator.pop(ctx, c.id),
          );
        }, childCount: list.length),
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: media.size.height * 0.88,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: text, fontSize: 15, inherit: false),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: bar,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title ?? t.categoryPickTitle,
                            style: TextStyle(
                              color: text,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (widget.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 14,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: t.cancel,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        onPressed: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: card,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.x, size: 16, color: muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CupertinoSearchTextField(
                  controller: _search,
                  placeholder: t.categorySearch,
                  backgroundColor: card,
                  style: TextStyle(color: text),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text(
                          t.categoryNoMatch,
                          style: TextStyle(
                            color: muted,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          if (suggested.isNotEmpty) ...[
                            heading(t.categorySuggested.toUpperCase()),
                            grid(suggested),
                          ],
                          for (final g in CategoryGroup.values)
                            if (byGroup[g] != null) ...[
                              heading(groupLabel(t, g).toUpperCase()),
                              grid(byGroup[g]!),
                            ],
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],
                      ),
              ),
              if (widget.removeLabel != null)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    media.padding.bottom + 12,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(top: BorderSide(color: bar)),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context, ''),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        widget.removeLabel!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                          color: widget.removeIsDestructive
                              ? AppColors.danger.resolveFrom(context)
                              : text,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.category,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final Category category;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppTokens.card.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    final group = groupOf(category.name);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? AppTokens.okBg.resolveFrom(context) : card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? accent : const Color(0x00000000),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: groupColor(group),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          categoryIcon(category),
                          size: 22,
                          color: const Color(0xFF0B0F14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: text,
                            fontSize: 13,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selected)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.check,
                    size: 12,
                    color: AppTokens.onAccent.resolveFrom(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
