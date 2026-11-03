import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/capture_bridge.dart';
import '../../core/capture_setup.dart';
import '../../core/lock.dart';
import '../../core/providers.dart';
import '../../core/reminders.dart';
import '../../core/widget_bridge.dart';
import '../../core/widget_setup.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/theme.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.language),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'en'),
            child: Text(t.languageEnglish),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'ar'),
            child: Text(t.languageArabic),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.cancel),
        ),
      ),
    );
    if (choice != null) await ref.read(localeProvider.notifier).set(choice);
  }

  Future<void> _toggleReminders(
    BuildContext context,
    WidgetRef ref,
    bool on,
  ) async {
    final controller = ref.read(remindersEnabledProvider.notifier);
    if (!on) {
      await controller.disable();
      return;
    }
    final t = AppLocalizations.of(context);
    final granted = await controller.enable();
    if (granted || !context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(t.remindersDenied),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.done),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(largeTitle: Text(t.tabMore)),
          SliverSafeArea(
            top: false,
            sliver: SliverList.list(
              children: [
                CupertinoListSection.insetGrouped(
                  children: [
                    CupertinoListTile.notched(
                      title: Text(t.language),
                      additionalInfo: Text(
                        locale.languageCode == 'ar'
                            ? t.languageArabic
                            : t.languageEnglish,
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _pickLanguage(context, ref),
                    ),
                    CupertinoListTile.notched(
                      title: Text(t.remindersTitle),
                      subtitle: Text(t.remindersHelp),
                      trailing: CupertinoSwitch(
                        value: ref.watch(remindersEnabledProvider),
                        onChanged: (on) => _toggleReminders(context, ref, on),
                      ),
                    ),
                    CupertinoListTile.notched(
                      title: Text(t.gapsTitle),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => context.go(gapsPath),
                    ),
                    _CaptureStatusTile(),
                    CupertinoListTile.notched(
                      title: Text(t.ingestToken),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => context.go(tokenPath),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  children: [
                    CupertinoListTile.notched(
                      title: Text(
                        t.signOut,
                        style: TextStyle(
                          color: AppColors.danger.resolveFrom(context),
                        ),
                      ),
                      onTap: () async {
                        await releaseCapture(
                          ref.read(captureBridgeProvider),
                          ref.read(tokenRepositoryProvider),
                        );
                        await releaseWidget(
                          ref.read(widgetBridgeProvider),
                          ref.read(tokenRepositoryProvider),
                        );
                        await ref.read(authRepositoryProvider).signOut();
                        ref.read(lockProvider.notifier).lockNow();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows what the "Add bank message" Shortcuts action has queued and how the last send went. Tap to retry now.
class _CaptureStatusTile extends ConsumerWidget {
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
    return CupertinoListTile.notched(
      title: Text(t.captureStatus),
      subtitle: Text(last.isEmpty ? waiting : '$waiting · $last'),
      trailing: const CupertinoListTileChevron(),
      onTap: () => context.go(capturePath),
    );
  }
}
