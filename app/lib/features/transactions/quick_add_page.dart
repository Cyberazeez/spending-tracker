import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/app_form.dart';
import '../../ui/tokens.dart';
import '../paste/paste_entry_row.dart';
import 'manual_form.dart';
import 'providers.dart';

class QuickAddPage extends ConsumerWidget {
  const QuickAddPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.homeAddTx),
      child: SafeArea(
        child: ManualTxnForm(
          header: PasteEntryRow(
            title: t.pasteTitle,
            hint: t.pasteRowHint,
            onTap: () => context.push(pastePath),
            orLine: t.pasteOrManual,
          ),
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
