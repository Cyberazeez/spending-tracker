import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/lock.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/empty_state.dart';
import '../../ui/skeleton.dart';
import '../../ui/tokens.dart';
import 'logic.dart';
import 'obligations_page.dart' show billRow;
import 'providers.dart';
import 'widgets/bills_widgets.dart';

/// Bills > History: every bill from the months before this one, newest month first, each with its status (a bill
/// still open shows Overdue here too, and stays on Bills until it is paid).
class BillsHistoryPage extends ConsumerWidget {
  const BillsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final today = riyadhToday(ref.watch(clockProvider)());
    final muted = AppTokens.muted.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.obHistoryTitle),
      child: SafeArea(
        child: ref
            .watch(obligationsProvider)
            .when(
              loading: () => const SkeletonList(heights: [160, 200]),
              error: (_, _) => LoadFailedCard(
                onRetry: () => ref.invalidate(obligationsProvider),
              ),
              data: (all) {
                final rows = billsHistory(all, today);
                if (rows.isEmpty) {
                  return EmptyState(
                    art: EmptyArtKind.waiting,
                    title: t.obEmptyHistory,
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    for (final g in groupByCycle(rows)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                        child: Text(
                          '${monthName(g.monthStart, arabic: arabic)} ${ltrIsolate(g.monthStart.year.toString())}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ),
                      RowsCard(
                        children: [
                          for (final i in g.items)
                            billRow(context, i, today, arabic, t),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
      ),
    );
  }
}
