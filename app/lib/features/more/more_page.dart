import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/lock.dart';
import '../../core/providers.dart';
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
