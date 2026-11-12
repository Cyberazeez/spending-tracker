import 'package:flutter/cupertino.dart';

import 'app_card.dart';
import 'tokens.dart';

/// Placeholder cards shown while the first data loads (no spinner): outlined cards holding grey rows shaped like
/// the list rows that will replace them.
class SkeletonSliver extends StatelessWidget {
  const SkeletonSliver({super.key, required this.heights});

  /// Height of each placeholder card.
  final List<double> heights;

  @override
  Widget build(BuildContext context) {
    final fill = AppTokens.bar.resolveFrom(context);
    Widget block(double w, double h, {double r = 8}) => DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(r),
      ),
      child: SizedBox(width: w, height: h),
    );
    final row = Row(
      children: [
        block(42, 42, r: AppTokens.radiusTile),
        const SizedBox(width: 12),
        Expanded(
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(double.infinity, 14),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: block(double.infinity, 11),
                ),
              ],
            ),
          ),
        ),
        block(56, 14),
      ],
    );
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverList.list(
        children: [
          for (final h in heights)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                height: h,
                child: AppCard(
                  flat: true,
                  padding: const EdgeInsets.all(16),
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: double.infinity,
                      child: Column(
                        children: [
                          for (
                            var i = 0;
                            i < ((h - 32 + 18) / 60).floor().clamp(1, 9);
                            i++
                          )
                            Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: row,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
