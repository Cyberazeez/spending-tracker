import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lock.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/launch_skeleton.dart';
import '../../ui/tokens.dart';

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
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: LaunchSkeleton(
        child: Align(
          alignment: const Alignment(0, 0.55),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t.lockTitle,
                  style: TextStyle(
                    color: AppTokens.text.resolveFrom(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (state.failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    t.unlockFailed,
                    style: TextStyle(
                      color: AppTokens.text.resolveFrom(context),
                      fontSize: 15,
                    ),
                  ),
                ),
              SizedBox(
                width: 220,
                child: PrimaryButton(
                  label: t.unlock,
                  onPressed: state.busy ? null : _unlock,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
