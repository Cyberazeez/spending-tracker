import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The "opens something" arrow at the end of a row: points right in English and left in Arabic.
class ForwardChevron extends StatelessWidget {
  const ForwardChevron({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
      size: size,
      color: color,
    );
  }
}
