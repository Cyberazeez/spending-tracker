import 'package:flutter/cupertino.dart';

import 'icon_tile.dart';
import 'tokens.dart';

/// The neutral sand tile of an empty or failed state (no colour that would call it good or bad).
const emptyTileColor = Color(0xFFDDE3CC);

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final secondary = AppTokens.muted.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(color: emptyTileColor, icon: icon, size: 64, iconSize: 30),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
