import 'package:flutter/cupertino.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import 'app_card.dart';
import 'app_form.dart';
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

/// A tab or page that could not load: an outlined card with a coral warning tile, what happened, and Try again.
/// Sits at the top of the page.
class LoadFailedCard extends StatelessWidget {
  const LoadFailedCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconTile(
                color: Color(0xFFFFA574),
                icon: LucideIcons.triangleAlert,
                size: 64,
                radius: 16,
                iconSize: 30,
              ),
              const SizedBox(height: 14),
              Text(
                t.loadFailed,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTokens.text.resolveFrom(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.loadFailedBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTokens.muted.resolveFrom(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: t.tryAgain,
                icon: LucideIcons.refreshCw,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
