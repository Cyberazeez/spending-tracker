import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/capture_bridge.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/bottom_inset.dart';

/// Walks through the one Shortcuts automation that feeds bank SMS to the app, and shows whether it is working.
class CapturePage extends ConsumerWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final status = ref.watch(captureStatusProvider).value;
    final waiting = status == null
        ? ''
        : (status.pending == 0
              ? t.captureNone
              : t.captureWaiting(status.pending));
    final last = status?.last ?? '';
    final steps = [
      t.captureStep1,
      t.captureStep2,
      t.captureStep3,
      t.captureStep4,
      t.captureStep5,
    ];
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(t.captureSetupTitle),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => context.go(homePath),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(t.captureIntro),
                ),
                CupertinoListSection.insetGrouped(
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      CupertinoListTile(
                        leading: Text('${i + 1}'),
                        title: Text(steps[i]),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CupertinoButton.filled(
                    onPressed: () =>
                        ref.read(captureBridgeProvider).openShortcuts(),
                    child: Text(t.captureOpenShortcuts),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  header: Text(t.captureStatusHeader),
                  footer: Text(t.captureHelp),
                  children: [
                    CupertinoListTile(
                      title: Text(waiting),
                      subtitle: last.isEmpty ? null : Text(last),
                    ),
                    CupertinoListTile(
                      title: Text(t.captureSendNow),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () async {
                        await ref.read(captureBridgeProvider).flush();
                        ref.invalidate(captureStatusProvider);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const BottomInset(),
          ],
        ),
      ),
    );
  }
}
