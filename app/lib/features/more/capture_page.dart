import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'capture_label.dart';
import 'shortcut_guide.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/capture_bridge.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/tokens.dart';

/// The one Shortcuts automation that feeds bank SMS to the app: five short steps and whether it is working.
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
    final last = captureLastLabel(t, status?.last ?? '');
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);
    final steps = [
      t.captureStep1,
      t.captureStep2,
      t.captureStep3,
      t.captureStep4,
      t.captureStep5,
    ];
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.captureSetupTitle),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList.list(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Text(
                      t.captureIntro,
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                  ),
                  AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          color: AppTokens.accentText
                                              .resolveFrom(context),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      steps[i],
                                      style: TextStyle(
                                        color: text,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: () => showShortcutGuide(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.images,
                          size: 18,
                          color: AppTokens.accentText.resolveFrom(context),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            t.captureGuideOpen,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTokens.accentText.resolveFrom(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  PrimaryButton(
                    label: t.captureOpenShortcuts,
                    onPressed: () =>
                        ref.read(captureBridgeProvider).openShortcuts(),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          waiting,
                          style: TextStyle(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (last.isNotEmpty)
                          Text(
                            last,
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 44),
                          alignment: AlignmentDirectional.centerStart,
                          onPressed: () async {
                            await ref.read(captureBridgeProvider).flush();
                            ref.invalidate(captureStatusProvider);
                          },
                          child: Text(
                            t.captureSendNow,
                            style: TextStyle(
                              color: AppTokens.accentText.resolveFrom(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
