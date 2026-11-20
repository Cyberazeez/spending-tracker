import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/app_card.dart';
import '../../ui/chevron.dart';
import '../../ui/icon_tile.dart';
import '../../ui/tokens.dart';

/// The gold "Paste a bank message" / "Paste a bill message" row on Add a transaction and Add a bill, with an
/// optional "or enter it yourself" divider under it.
class PasteEntryRow extends StatelessWidget {
  const PasteEntryRow({
    super.key,
    required this.title,
    required this.hint,
    required this.onTap,
    this.orLine,
  });

  final String title;
  final String hint;
  final VoidCallback onTap;
  final String? orLine;

  @override
  Widget build(BuildContext context) {
    final ink = AppTokens.onTint.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: '$title, $hint',
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey('paste-entry'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AppCard(
              pressable: true,
              color: AppTokens.gold.resolveFrom(context),
              child: Row(
                children: [
                  IconTile(
                    color: const Color(0xFFFFFFFF),
                    icon: LucideIcons.clipboardPaste,
                    size: 44,
                    iconSize: 20,
                    outline: ink,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hint,
                          style: TextStyle(
                            color: ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ForwardChevron(size: 16, color: ink),
                ],
              ),
            ),
          ),
        ),
        if (orLine != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: AppTokens.bar.resolveFrom(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    orLine!,
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: AppTokens.bar.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
