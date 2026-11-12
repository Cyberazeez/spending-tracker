import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/banks.dart';
import '../../core/capture_bridge.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/icon_tile.dart';
import '../../ui/settings_group.dart' show dangerTileColor;
import '../../ui/tokens.dart';
import '../account/account_providers.dart';
import '../obligations/widgets/bills_widgets.dart' show PillTone, StatusPill;
import '../transactions/providers.dart' show senderGapsProvider;
import 'capture_label.dart';
import 'shortcut_guide.dart';

/// One bank (or other sender) on the SMS capture page and when its last message arrived (null: none yet).
class CaptureSource {
  const CaptureSource(this.label, this.lastReceivedAt);
  final String label;
  final DateTime? lastReceivedAt;
}

/// The banks to list: every sender a message came from, and every bank of the owner's accounts that has sent
/// nothing yet. Senders of the same bank are one row (its newest message counts).
List<CaptureSource> captureSources(
  List<SenderGap> gaps,
  List<OwnAccount> accounts,
  AppLocalizations t, {
  required bool arabic,
}) {
  final byKey = <String, (String, DateTime?)>{};
  void add(String key, String label, DateTime? at) {
    final old = byKey[key];
    final keep = old?.$2 == null || (at != null && at.isAfter(old!.$2!))
        ? at
        : old!.$2;
    byKey[key] = (label, keep);
  }

  for (final g in gaps) {
    final code = bankCodeForSender(g.sender);
    if (code != null) {
      add(code, bankDisplayName(code, arabic: arabic), g.lastReceivedAt);
    } else if (g.sender.trim() == '900') {
      add('900', t.capBills, g.lastReceivedAt);
    } else {
      add('s:${g.sender}', g.sender, g.lastReceivedAt);
    }
  }
  for (final a in accounts) {
    if (!byKey.containsKey(a.bank)) {
      add(a.bank, bankDisplayName(a.bank, arabic: arabic), null);
    }
  }
  return [for (final v in byKey.values) CaptureSource(v.$1, v.$2)]
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
}

/// More > SMS capture: whether the Shortcuts automation works, which banks have sent messages, and the guide.
class CapturePage extends ConsumerWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final status = ref.watch(captureStatusProvider).value;
    final gaps = ref.watch(senderGapsProvider).value ?? const <SenderGap>[];
    final accounts = ref.watch(ownAccountsProvider).value ?? const [];
    final sources = captureSources(gaps, accounts, t, arabic: arabic);
    final muted = AppTokens.muted.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.captureStatus),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList.list(
                children: [
                  _StatusCard(status: status),
                  if (sources.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      key: const ValueKey('capture-banks'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < sources.length; i++) ...[
                            if (i > 0)
                              SizedBox(
                                height: 2,
                                child: ColoredBox(
                                  color: AppTokens.bar.resolveFrom(context),
                                ),
                              ),
                            _SourceRow(source: sources[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                    key: const ValueKey('capture-guide'),
                    label: t.captureGuideOpen,
                    icon: LucideIcons.smartphone,
                    onPressed: () => showShortcutGuide(context),
                  ),
                  const SizedBox(height: 4),
                  SecondaryButton(
                    key: const ValueKey('capture-shortcuts'),
                    label: t.captureOpenShortcuts,
                    onPressed: () =>
                        ref.read(captureBridgeProvider).openShortcuts(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                    child: Text(
                      t.capPrivacy,
                      style: TextStyle(
                        color: muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const BottomInset(),
          ],
        ),
      ),
    );
  }
}

/// The big card on top: working (mint), refused by the server (pink), or not set up / offline / nothing sent yet
/// (gold). Messages
/// waiting on the phone are counted, with a link to send them now.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.status});

  final CaptureStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final s = status;
    final result = s == null ? CaptureResult.none : captureResult(s.last);
    final gold = AppTokens.gold.resolveFrom(context);
    final (Color fill, IconData icon, String title, String body) = switch (s) {
      null => (
        AppTokens.card.resolveFrom(context),
        LucideIcons.messageSquare,
        t.captureStatus,
        '',
      ),
      _ when !s.hasToken || result == CaptureResult.noToken => (
        gold,
        LucideIcons.messageSquare,
        t.capNotSetUp,
        t.capNotSetUpBody,
      ),
      // The server refused the message (a real failure; 401/403 mean the phone must sign in again).
      _ when result == CaptureResult.failed => (
        dangerTileColor,
        LucideIcons.triangleAlert,
        t.capFailing,
        captureLastLabel(t, s.last),
      ),
      // Offline for a moment: the messages wait on the phone and are retried, so it is not a failure.
      _ when result == CaptureResult.offline => (
        gold,
        LucideIcons.wifiOff,
        t.capOffline,
        t.capOfflineBody,
      ),
      _ when result == CaptureResult.sent => (
        AppTokens.okBg.resolveFrom(context),
        LucideIcons.check,
        t.capWorking,
        captureLastLabel(t, s.last),
      ),
      _ when result == CaptureResult.none => (
        gold,
        LucideIcons.hourglass,
        t.capWaitingFirst,
        t.captureNone,
      ),
      // Queued (the shortcut stopped before sending) or a shape this app does not know.
      _ => (gold, LucideIcons.hourglass, t.capQueued, ''),
    };
    // Text sits on a pastel fill (or the plain card while loading).
    final ink = s == null
        ? AppTokens.text.resolveFrom(context)
        : AppTokens.onTint.resolveFrom(context);
    final pending = s?.pending ?? 0;
    // "Send now" needs the phone's credentials; without them the native flush does nothing.
    final canSend = pending > 0 && (s?.hasToken ?? false);
    final lines = [
      if (body.isNotEmpty && !(result == CaptureResult.none && pending > 0))
        body,
      if (pending > 0) t.captureWaiting(pending),
    ];
    return AppCard(
      key: const ValueKey('capture-status'),
      color: fill,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // A fixed white tile: the icon is ink in both modes, so the dark card colour would hide it.
              IconTile(
                color: const Color(0xFFFFFFFF),
                icon: icon,
                size: 52,
                radius: 14,
                iconSize: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (lines.isNotEmpty)
                      Text(
                        lines.join(' · '),
                        style: TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (canSend)
            CupertinoButton(
              key: const ValueKey('capture-send-now'),
              padding: const EdgeInsetsDirectional.only(start: 66),
              minimumSize: const Size(44, 44),
              alignment: AlignmentDirectional.centerStart,
              onPressed: () async {
                await ref.read(captureBridgeProvider).flush();
                ref.invalidate(captureStatusProvider);
              },
              child: Text(
                t.captureSendNow,
                style: TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                  decorationColor: ink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final CaptureSource source;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final seen = source.lastReceivedAt != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                source.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTokens.text.resolveFrom(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // At the row's end; shrinks rather than overflow with large text.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: StatusPill(
                  label: seen ? t.capConnected : t.capNoMessages,
                  tone: seen ? PillTone.ok : PillTone.warn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
