import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/empty_state.dart';
import '../transactions/providers.dart';

/// Senders the app expects. One that never sent anything is shown as such, so a missing Shortcut is visible.
const expectedSenders = [
  'alinma',
  'barq app',
  'D360 Bank',
  'STC Bank',
  'SNB-AlAhli',
  'AlRajhiBank',
];

class GapsPage extends ConsumerWidget {
  const GapsPage({super.key, this.now});

  /// Injectable for tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final gaps = ref.watch(senderGapsProvider);
    final clock = now ?? DateTime.now;
    ref.watch(localeProvider);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(t.gapsTitle),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => context.go(homePath),
        ),
      ),
      child: SafeArea(
        child: gaps.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, _) => EmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: t.loadFailed,
            action: CupertinoButton(
              onPressed: () => ref.invalidate(senderGapsProvider),
              child: Text(t.tryAgain),
            ),
          ),
          data: (seen) {
            final known = {for (final g in seen) g.sender.toLowerCase()};
            final list = [
              ...seen,
              for (final e in expectedSenders)
                if (!known.contains(e.toLowerCase())) SenderGap(sender: e),
            ];
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    t.gapsIntro,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  children: [
                    for (final g in list)
                      CupertinoListTile(
                        title: Text(g.sender),
                        subtitle: Text(
                          g.lastReceivedAt == null
                              ? t.gapsNever
                              : t.gapsLast(formatDateTime(g.lastReceivedAt!)),
                        ),
                        additionalInfo: g.lastReceivedAt == null
                            ? null
                            : Text(
                                _ago(
                                  t,
                                  clock().toUtc().difference(g.lastReceivedAt!),
                                ),
                              ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _ago(AppLocalizations t, Duration d) =>
      d.inDays < 1 ? t.gapsToday : t.gapsDays(d.inDays);
}
