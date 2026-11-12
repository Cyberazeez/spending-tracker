import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/money.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'tokens.dart';

/// The frame of the app's bottom sheets: rounded top, grabber, a title with an optional subtitle and a close button.
/// The sheet sits above the keyboard when it is open.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final bg = AppTokens.bg.resolveFrom(context);
    final card = AppTokens.card.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final bar = AppTokens.bar.resolveFrom(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTokens.radiusSheet),
            ),
            border: outlineOf(context),
          ),
          child: SingleChildScrollView(
            child: DefaultTextStyle(
              style: TextStyle(
                color: text,
                fontSize: 15,
                inherit: false,
                fontFamily: appFont,
                fontFamilyFallback: const [riyalFont],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      decoration: BoxDecoration(
                        color: bar,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      10,
                      12,
                      6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: text,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              if (subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 14,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: t.cancel,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 44),
                            onPressed: () => Navigator.pop(context),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: card,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.x,
                                size: 16,
                                color: muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  child,
                  SizedBox(height: media.padding.bottom + 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
