import 'package:flutter/cupertino.dart';

import '../core/money.dart';
import 'tokens.dart';

class AppColors {
  static const accent = AppTokens.accent;
  static const danger = AppTokens.danger;
}

/// The app typeface (bundled, Latin and Arabic). The riyal sign comes from [riyalFont] through the fallback.
const appFont = 'Rubik';

const _defaults = CupertinoTextThemeData();

TextStyle _rubik(TextStyle base, {Color? color}) => base.copyWith(
  fontFamily: appFont,
  fontFamilyFallback: const [riyalFont],
  letterSpacing: 0,
  color: color,
);

final appTheme = CupertinoThemeData(
  primaryColor: AppColors.accent,
  scaffoldBackgroundColor: AppTokens.bg,
  barBackgroundColor: AppTokens.bg,
  textTheme: CupertinoTextThemeData(
    primaryColor: AppTokens.accentText,
    textStyle: _rubik(_defaults.textStyle, color: AppTokens.text),
    actionTextStyle: _rubik(
      _defaults.actionTextStyle,
      color: AppTokens.accentText,
    ),
    navActionTextStyle: _rubik(
      _defaults.navActionTextStyle,
      color: AppTokens.accentText,
    ),
    navTitleTextStyle: _rubik(
      _defaults.navTitleTextStyle,
      color: AppTokens.text,
    ).copyWith(fontWeight: FontWeight.w700),
    navLargeTitleTextStyle: _rubik(
      _defaults.navLargeTitleTextStyle,
      color: AppTokens.text,
    ).copyWith(fontWeight: FontWeight.w800),
    tabLabelTextStyle: _rubik(_defaults.tabLabelTextStyle),
    pickerTextStyle: _rubik(_defaults.pickerTextStyle, color: AppTokens.text),
    dateTimePickerTextStyle: _rubik(
      _defaults.dateTimePickerTextStyle,
      color: AppTokens.text,
    ),
  ),
);
