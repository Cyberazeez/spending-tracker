import 'package:flutter/cupertino.dart';

import '../../ui/trailing_box.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/empty_state.dart';
import '../../ui/skeleton.dart';
import '../../ui/tokens.dart';
import '../ai/widgets/suggest_categories_card.dart';
import '../obligations/logic.dart' show riyadhToday;
import 'category_actions.dart';
import 'day_groups.dart';
import 'providers.dart';
import 'widgets/filter_chips.dart';
import 'widgets/txn_row.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final filter = ref.watch(txFilterProvider);
    final txns = ref.watch(transactionsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final reviewCount = ref.watch(reviewCountProvider);
    final byId = {for (final c in cats) c.id: c};
    final today = riyadhToday(ref.watch(clockProvider)());

    String dayLabel(DateTime d) {
      final diff = today.difference(d).inDays;
      if (diff == 0) return t.txToday;
      if (diff == 1) return t.txYesterday;
      return '${DateFormat('EEE', arabic ? 'ar' : 'en').format(d)} ${formatDay(d)}';
    }

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(t.txTitle),
            backgroundColor: AppTokens.bg.resolveFrom(context),
            border: null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () => showFilterSheet(context, ref),
                  child: Icon(
                    LucideIcons.listFilter,
                    color:
                        filter.categoryId != null ||
                            filter.uncategorizedOnly ||
                            filter.hideInternal
                        ? AppTokens.accent.resolveFrom(context)
                        : AppTokens.text.resolveFrom(context),
                    semanticLabel: t.filterTitle,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () => context.push(quickAddPath),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTokens.accent.resolveFrom(context),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        LucideIcons.plus,
                        size: 20,
                        color: AppTokens.onAccent.resolveFrom(context),
                        semanticLabel: t.homeAddTx,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(needsReviewProvider);
              ref.invalidate(aiReadProvider);
              ref.invalidate(categoriesProvider);
              await Future.wait([
                ref
                    .read(transactionsProvider.future)
                    .catchError((_) => <Txn>[]),
                ref
                    .read(needsReviewProvider.future)
                    .catchError((_) => <RawMessage>[]),
              ]);
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SearchBox(),
                  const SizedBox(height: 8),
                  FilterChips(
                    reviewCount: reviewCount,
                    onReview: () => context.push(reviewPath),
                  ),
                ],
              ),
            ),
          ),
          ...txns.when(
            loading: () => [
              const SkeletonSliver(heights: [150, 200, 150]),
            ],
            error: (_, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: CupertinoIcons.exclamationmark_triangle,
                  title: t.loadFailed,
                  action: CupertinoButton(
                    onPressed: () => ref.invalidate(transactionsProvider),
                    child: Text(t.tryAgain),
                  ),
                ),
              ),
            ],
            data: (list) => list.isEmpty
                ? [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: filter.isActive
                          ? EmptyState(
                              icon: CupertinoIcons.search,
                              title: t.noMatches,
                              action: CupertinoButton(
                                onPressed: () =>
                                    ref.read(txFilterProvider.notifier).clear(),
                                child: Text(t.filterClear),
                              ),
                            )
                          : EmptyState(
                              icon: CupertinoIcons.tray,
                              title: t.txEmptyTitle,
                              body: t.txEmptyBody,
                              action: PrimaryButton(
                                label: t.quickAdd,
                                onPressed: () => context.push(quickAddPath),
                              ),
                            ),
                    ),
                  ]
                : [
                    SliverToBoxAdapter(
                      child: SuggestCategoriesCard(
                        uncategorized:
                            ref.watch(uncategorizedCountProvider).value ?? 0,
                      ),
                    ),
                    Builder(
                      builder: (_) {
                        final groups = groupByDay(
                          list,
                          excludedCategories: {
                            for (final c in cats)
                              if (c.excludedFromSpend) c.id,
                          },
                        );
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          sliver: SliverList.builder(
                            itemCount: groups.length,
                            itemBuilder: (_, i) => _DayBlock(
                              label: dayLabel(groups[i].day),
                              group: groups[i],
                              arabic: arabic,
                              byId: byId,
                              onPick: (txn) =>
                                  pickCategory(context, ref, txn, cats),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
          ),
          const BottomInset(),
        ],
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({
    required this.label,
    required this.group,
    required this.arabic,
    required this.byId,
    required this.onPick,
  });

  final String label;
  final DayGroup group;
  final bool arabic;
  final Map<String, Category> byId;
  final void Function(Txn) onPick;

  @override
  Widget build(BuildContext context) {
    final muted = AppTokens.muted.resolveFrom(context);
    final line = muted.withValues(alpha: 0.18);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: _DayHeader(
              label: label,
              total: group.spendHalalas > 0
                  ? formatSar(group.spendHalalas, arabic: arabic)
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                for (var i = 0; i < group.items.length; i++) ...[
                  TxnRow(
                    txn: group.items[i],
                    arabic: arabic,
                    category: byId[group.items[i].categoryId],
                    onTap: () => onPick(group.items[i]),
                  ),
                  if (i < group.items.length - 1)
                    SizedBox(height: 1, child: ColoredBox(color: line)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Today" and the day's spend; the spend drops under the label at large text sizes.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.total});

  final String label;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    final labelText = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w600),
    );
    final totalText = total == null
        ? null
        : Directionality(
            textDirection: TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(total!, style: TextStyle(color: muted, fontSize: 13)),
            ),
          );
    if (stacked || totalText == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelText, ?totalText],
      );
    }
    return Row(
      children: [
        Expanded(child: labelText),
        const SizedBox(width: 8),
        TrailingBox(child: totalText),
      ],
    );
  }
}

/// The search field keeps its own controller so "Clear filters" also empties the box.
class _SearchBox extends ConsumerStatefulWidget {
  const _SearchBox();

  @override
  ConsumerState<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends ConsumerState<_SearchBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(txFilterProvider, (_, next) {
      if (next.query.isEmpty && _controller.text.trim().isNotEmpty) {
        _controller.clear();
      }
    });
    return CupertinoSearchTextField(
      controller: _controller,
      placeholder: AppLocalizations.of(context).searchHint,
      backgroundColor: AppTokens.card.resolveFrom(context),
      borderRadius: BorderRadius.circular(16),
      // 44 pt tall (the default is 36): the smallest comfortable tap target on iOS
      padding: const EdgeInsetsDirectional.fromSTEB(8, 14, 8, 14),
      onChanged: (v) {
        final ctl = ref.read(txFilterProvider.notifier);
        ctl.set(ref.read(txFilterProvider).copyWith(query: v.trim()));
      },
    );
  }
}
