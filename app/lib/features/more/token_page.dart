import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/token_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/theme.dart';

final activeTokenProvider = FutureProvider.autoDispose<IngestTokenInfo?>(
  (ref) => ref.watch(tokenRepositoryProvider).activeToken(),
);

class TokenPage extends ConsumerStatefulWidget {
  const TokenPage({super.key});

  @override
  ConsumerState<TokenPage> createState() => _TokenPageState();
}

class _TokenPageState extends ConsumerState<TokenPage> {
  String? _newToken;
  bool _busy = false;
  bool _failed = false;

  Future<void> _rotate(bool hasActive) async {
    final t = AppLocalizations.of(context);
    if (hasActive) {
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(t.tokenConfirmTitle),
          content: Text(t.tokenConfirmBody),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.continueLabel),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final token = await ref.read(tokenRepositoryProvider).rotate();
      setState(() => _newToken = token);
      ref.invalidate(activeTokenProvider);
    } catch (_) {
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final active = ref.watch(activeTokenProvider);
    final info = active.value;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(t.tokenScreenTitle),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => context.go(homePath),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                t.tokenIntro,
                style: TextStyle(color: secondary, fontSize: 15),
              ),
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: Text(t.ingestUrl),
                  subtitle: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(AppConfig.ingestUrl),
                  ),
                ),
                CupertinoListTile(
                  title: Text(t.ingestHeader),
                  subtitle: const Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text('X-Ingest-Token'),
                  ),
                ),
                CupertinoListTile(
                  title: Text(t.tokenStatus),
                  subtitle: Text(
                    active.isLoading
                        ? '…'
                        : info == null
                        ? t.tokenNone
                        : '${t.tokenActive(formatDateTime(info.createdAt))}\n'
                              '${info.lastUsedAt == null ? t.tokenNeverUsed : t.tokenLastUsed(formatDateTime(info.lastUsedAt!))}',
                  ),
                ),
              ],
            ),
            if (_newToken != null)
              CupertinoListSection.insetGrouped(
                header: Text(t.tokenShownOnce),
                children: [
                  CupertinoListTile(
                    title: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        _newToken!,
                        style: const TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text(t.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _newToken!),
                        );
                        if (context.mounted) {
                          ScaffoldMessengerLessToast.show(
                            context,
                            t.tokenCopied,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  t.genericError,
                  style: TextStyle(
                    color: AppColors.danger.resolveFrom(context),
                    fontSize: 13,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: CupertinoButton.filled(
                onPressed: _busy || active.isLoading
                    ? null
                    : () => _rotate(info != null),
                child: _busy
                    ? const CupertinoActivityIndicator()
                    : Text(info == null ? t.tokenGenerate : t.tokenRotate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal toast so the page does not depend on Material's ScaffoldMessenger.
class ScaffoldMessengerLessToast {
  static void show(BuildContext context, String text) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 96,
        left: 0,
        right: 0,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                text,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 1), entry.remove);
  }
}
