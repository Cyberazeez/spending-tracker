import 'package:flutter/cupertino.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import 'app_card.dart';
import 'app_form.dart';
import 'empty_art.dart';
import 'icon_tile.dart';
import 'tokens.dart';

export 'empty_art.dart' show EmptyArt, EmptyArtKind;

/// An empty screen: the brand picture ([EmptyArt]: the logo waiting for its coins, or whole for good news), a title,
/// an optional line of help and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.art = EmptyArtKind.waiting,
    required this.title,
    this.body,
    this.action,
  });

  final EmptyArtKind art;
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
            EmptyArt(kind: art),
            const SizedBox(height: 18),
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
