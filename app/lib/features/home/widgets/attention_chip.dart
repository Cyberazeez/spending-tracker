import 'package:flutter/cupertino.dart';

import '../../../ui/tokens.dart';

/// A small pill with a colored dot, e.g. "2 to review". Tapping it opens the thing it counts.
class AttentionChip extends StatelessWidget {
  const AttentionChip({
    super.key,
    required this.label,
    required this.dot,
    required this.onTap,
  });

  final String label;
  final Color dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTokens.card.resolveFrom(context),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppTokens.text.resolveFrom(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
