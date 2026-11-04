import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/app_form.dart';
import '../../ui/tokens.dart';
import 'manual_form.dart';
import 'providers.dart';

class QuickAddPage extends ConsumerWidget {
  const QuickAddPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.quickAdd),
      child: SafeArea(
        child: ManualTxnForm(
          onSave: (txn) async {
            await ref.read(dataRepositoryProvider).addManual(txn);
            ref.invalidate(transactionsProvider);
            if (context.mounted) popOrHome(context);
          },
        ),
      ),
    );
  }
}
