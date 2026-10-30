import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/lock.dart';
import 'core/providers.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'ui/theme.dart';

class SpendingTrackerApp extends ConsumerStatefulWidget {
  const SpendingTrackerApp({super.key});

  @override
  ConsumerState<SpendingTrackerApp> createState() => _SpendingTrackerAppState();
}

class _SpendingTrackerAppState extends ConsumerState<SpendingTrackerApp> {
  late final AppLifecycleListener _lifecycle;
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: () => setState(() => _covered = true),
      onResume: () {
        setState(() => _covered = false);
        ref.read(lockProvider.notifier).onForeground();
      },
      onHide: () => ref.read(lockProvider.notifier).onBackground(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return CupertinoApp.router(
      routerConfig: router,
      locale: locale,
      theme: appTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      // Hide content in the app switcher snapshot.
      builder: (context, child) => Stack(
        children: [
          ?child,
          if (_covered)
            Positioned.fill(
              child: ColoredBox(
                color: CupertinoColors.systemBackground.resolveFrom(context),
              ),
            ),
        ],
      ),
    );
  }
}
