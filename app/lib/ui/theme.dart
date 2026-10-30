import 'package:flutter/cupertino.dart';

class AppColors {
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0A7E6B),
    darkColor: Color(0xFF3CC4A8),
  );
  static const danger = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC5221F),
    darkColor: Color(0xFFFF6B66),
  );
}

const appTheme = CupertinoThemeData(primaryColor: AppColors.accent);
