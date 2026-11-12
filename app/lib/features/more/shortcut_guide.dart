import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';

/// The snippets (cropped from real screenshots, the tap target outlined) shown on each page of the guide.
const shortcutGuideImages = [
  'assets/guide/step1.webp',
  'assets/guide/step2.webp',
  'assets/guide/step3.webp',
  'assets/guide/step4.webp',
  'assets/guide/step5.webp',
  'assets/guide/step6.webp',
  'assets/guide/step7.webp',
];

/// Where "the guide was already offered" is remembered, per account.
String shortcutGuideSeenKey(String? userId) => 'guide.seen.${userId ?? ''}';

/// Opens the step-by-step guide to adding the Shortcuts automation, as a swipeable bottom sheet.
/// [offer] is the automatic first-launch version: page one has a Skip button where Back would be.
Future<void> showShortcutGuide(BuildContext context, {bool offer = false}) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => ShortcutGuideSheet(offer: offer),
    );

class ShortcutGuideSheet extends StatefulWidget {
  const ShortcutGuideSheet({super.key, this.offer = false});

  final bool offer;

  @override
  State<ShortcutGuideSheet> createState() => _ShortcutGuideSheetState();
}

class _ShortcutGuideSheetState extends State<ShortcutGuideSheet> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    _controller.animateToPage(
      page,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final bg = AppTokens.bg.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);
    final bar = AppTokens.bar.resolveFrom(context);
    final card = AppTokens.card.resolveFrom(context);
    final titles = [
      t.captureGuide1Title,
      t.captureGuide2Title,
      t.captureGuide3Title,
      t.captureGuide4Title,
      t.captureGuide5Title,
      t.captureGuide6Title,
      t.captureGuide7Title,
    ];
    final bodies = [
      t.captureGuide1Body,
      t.captureGuide2Body,
      t.captureGuide3Body,
      t.captureGuide4Body,
      t.captureGuide5Body,
      t.captureGuide6Body,
      t.captureGuide7Body,
    ];
    final last = _page == titles.length - 1;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: media.size.height * 0.92,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: text,
            fontSize: 15,
            decoration: TextDecoration.none,
            inherit: false,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: bar,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.captureGuideTitle,
                        style: TextStyle(
                          color: text,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Icon(LucideIcons.x, size: 22, color: muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('guide-pages'),
                  controller: _controller,
                  itemCount: titles.length,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder: (_, i) => LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      // Short pages (a small snippet) are centred in the space instead of hugging the top.
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: box.maxHeight - 20,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.captureGuideStepOf(i + 1, titles.length),
                              style: TextStyle(
                                color: AppTokens.accentText.resolveFrom(
                                  context,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              titles[i],
                              style: TextStyle(
                                color: text,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.asset(
                                  shortcutGuideImages[i],
                                  width: double.infinity,
                                  fit: BoxFit.fitWidth,
                                  semanticLabel: titles[i],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              bodies[i],
                              style: TextStyle(
                                color: text,
                                fontSize: 17,
                                height: 1.35,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  12 + media.padding.bottom,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: _page == 0 && !widget.offer
                          ? null
                          : CupertinoButton(
                              key: _page == 0
                                  ? const ValueKey('guide-skip')
                                  : null,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                              alignment: AlignmentDirectional.centerStart,
                              onPressed: () => _page == 0
                                  ? Navigator.of(context).pop()
                                  : _go(_page - 1),
                              child: Text(
                                _page == 0
                                    ? t.captureGuideSkip
                                    : t.captureGuideBack,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < titles.length; i++)
                            Container(
                              width: i == _page ? 20 : 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i == _page ? accent : bar,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: CupertinoButton(
                        key: const ValueKey('guide-next'),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        alignment: AlignmentDirectional.centerEnd,
                        onPressed: () =>
                            last ? Navigator.of(context).pop() : _go(_page + 1),
                        child: Text(
                          last ? t.captureGuideDone : t.captureGuideNext,
                          style: TextStyle(
                            color: AppTokens.accentText.resolveFrom(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}
