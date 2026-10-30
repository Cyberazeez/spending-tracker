import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lock.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/empty_state.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  @override
  void initState() {
    super.initState();
    // Prompt as soon as the lock screen appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    await ref
        .read(lockProvider.notifier)
        .unlock(AppLocalizations.of(context).unlockReason);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = ref.watch(lockProvider);
    return CupertinoPageScaffold(
      child: EmptyState(
        icon: CupertinoIcons.lock_fill,
        title: t.lockTitle,
        body: state.failed ? t.unlockFailed : t.lockBody,
        action: CupertinoButton.filled(
          onPressed: state.busy ? null : _unlock,
          child: Text(t.unlock),
        ),
      ),
    );
  }
}
