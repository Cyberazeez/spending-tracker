import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon_tile.dart';
import '../../ui/settings_group.dart' show dangerTileColor;
import '../../ui/tokens.dart';
import '../home/category_groups.dart';
import '../home/group_style.dart';
import '../transactions/providers.dart';

/// The owner's merchant rules (place → category), newest data on every open.
final merchantRulesProvider = FutureProvider.autoDispose<List<MerchantRule>>(
  (ref) => ref.watch(dataRepositoryProvider).merchantRules(),
  retry: (_, _) => null,
);

/// More > Categories and rules: each category with the places that always go to it. A wrong rule can be deleted;
/// purchases it already filed keep their category. Adding or renaming categories is not here yet.
class RulesPage extends ConsumerWidget {
  const RulesPage({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MerchantRule r,
    String category,
  ) async {
    final t = AppLocalizations.of(context);
    final sure = await showConfirmSheet(
      context,
      title: t.rulesDeleteTitle,
      message: t.rulesDeleteBody(r.pattern, category),
      confirmLabel: t.rulesDeleteYes,
      destructive: true,
      icon: LucideIcons.trash2,
      iconColor: dangerTileColor,
    );
    if (sure != true || !context.mounted) return;
    try {
      await ref.read(dataRepositoryProvider).deleteMerchantRule(r.id);
    } catch (_) {
      if (context.mounted) {
        await showNoticeSheet(context, title: t.obSaveFailed);
      }
      return;
    }
    ref.invalidate(merchantRulesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final rules = ref.watch(merchantRulesProvider);
    final cats = ref.watch(categoriesProvider);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);

    Widget body;
    if (rules.hasError || cats.hasError) {
      body = LoadFailedCard(
        onRetry: () {
          ref.invalidate(merchantRulesProvider);
          ref.invalidate(categoriesProvider);
        },
      );
    } else if (!rules.hasValue || !cats.hasValue) {
      body = const Padding(
        padding: EdgeInsets.only(top: 40),
        child: CupertinoActivityIndicator(),
      );
    } else {
      final byCat = <String, List<MerchantRule>>{};
      for (final r in rules.value!) {
        (byCat[r.categoryId] ??= []).add(r);
      }
      final withRules = [
        for (final c in cats.value!)
          if (byCat.containsKey(c.id)) c,
      ];
      final without = [
        for (final c in cats.value!)
          if (!byCat.containsKey(c.id)) c,
      ];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(
              withRules.isEmpty ? t.rulesEmpty : t.rulesIntro,
              style: TextStyle(
                color: muted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          for (final c in withRules) ...[
            _CategoryCard(
              category: c,
              arabic: arabic,
              rules: byCat[c.id]!,
              onDelete: (r) =>
                  _delete(context, ref, r, c.label(arabic: arabic)),
            ),
            const SizedBox(height: 12),
          ],
          if (without.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.rulesCount(0),
                    style: TextStyle(
                      color: text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in without)
                        _CategoryChip(category: c, arabic: arabic),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.moreCategoriesRules),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [body],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.arabic,
    required this.rules,
    required this.onDelete,
  });

  final Category category;
  final bool arabic;
  final List<MerchantRule> rules;
  final ValueChanged<MerchantRule> onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final g = groupOf(category.name);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final line = AppTokens.bar.resolveFrom(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(color: groupColor(g), icon: groupIcon(g), size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label(arabic: arabic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      t.rulesCount(rules.length),
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < rules.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: SizedBox(height: 2, child: ColoredBox(color: line)),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rules[i].pattern,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Semantics(
                  key: ValueKey('rule-delete-${rules[i].id}'),
                  container: true,
                  button: true,
                  label: '${t.rulesDeleteYes}, ${rules[i].pattern}',
                  onTap: () => onDelete(rules[i]),
                  excludeSemantics: true,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: () => onDelete(rules[i]),
                    child: Icon(
                      LucideIcons.trash2,
                      size: 19,
                      color: AppTokens.danger.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.arabic});

  final Category category;
  final bool arabic;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppTokens.bg.resolveFrom(context),
      borderRadius: BorderRadius.circular(20),
      border: outlineOf(context, width: AppTokens.outlineThin),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        category.label(arabic: arabic),
        style: TextStyle(
          color: AppTokens.text.resolveFrom(context),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
