import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/models.dart';
import '../core/money.dart';
import '../features/home/category_groups.dart';
import '../features/home/group_style.dart';
import '../l10n/app_localizations.dart';
import 'app_form.dart';
import 'icon_tile.dart';
import 'theme.dart';
import 'tokens.dart';
import 'app_sheet.dart';
import 'press.dart';

IconData categoryIcon(Category c) => categoryIconByName(c.name);

/// A category's own icon by its name; names without one fall back to their group's icon.
IconData categoryIconByName(String name) => switch (name) {
  'Groceries' => LucideIcons.shoppingCart,
  'Dining' => LucideIcons.utensils,
  'Coffee' => LucideIcons.coffee,
  'Fuel' => LucideIcons.fuel,
  'Transport' => LucideIcons.bus,
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
  return showAppSheet<String>(
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
    final line = AppTokens.line.resolveFrom(context);
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
          mainAxisExtent: 74 + 2 * 13 * 1.25 * scale,
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
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusSheet),
          ),
          border: outlineOf(context),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: text,
            fontSize: 15,
            inherit: false,
            fontFamily: appFont,
            fontFamilyFallback: const [riyalFont],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: line.withValues(alpha: 0.35),
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
                              fontWeight: FontWeight.w800,
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
                        pressedOpacity: 1,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        onPressed: () => Navigator.pop(context),
                        child: PressShadow(
                          decoration: BoxDecoration(
                            color: card,
                            shape: BoxShape.circle,
                            border: outlineOf(
                              context,
                              width: AppTokens.outlineThin,
                            ),
                          ),
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(LucideIcons.x, size: 16, color: text),
                          ),
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
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    border: outlineOf(context),
                  ),
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
                    border: Border(
                      top: BorderSide(color: bar, width: AppTokens.outlineThin),
                    ),
                  ),
                  child: SecondaryButton(
                    label: widget.removeLabel!,
                    danger: widget.removeIsDestructive,
                    onPressed: () => Navigator.pop(context, ''),
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
    final accent = AppTokens.accent.resolveFrom(context);
    // The ring is drawn on the page colour: the deeper green keeps it above 3:1 there (emerald is 2.8:1).
    final ring = AppTokens.accentText.resolveFrom(context);
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
        child: Column(
          children: [
            // The chosen tile gets an emerald ring and a check, so the choice is not shown by colour alone.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  key: selected ? const ValueKey('category-selected') : null,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: selected ? ring : const Color(0x00000000),
                      width: 3,
                    ),
                  ),
                  child: IconTile(
                    color: groupColor(group),
                    icon: categoryIcon(category),
                    size: 56,
                    radius: 16,
                    iconSize: 26,
                  ),
                ),
                if (selected)
                  PositionedDirectional(
                    top: -4,
                    end: -4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: outlineOf(
                          context,
                          width: AppTokens.outlineThin,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.check,
                        size: 13,
                        color: AppTokens.onAccent.resolveFrom(context),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
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
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
