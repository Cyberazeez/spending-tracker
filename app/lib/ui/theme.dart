import 'package:flutter/cupertino.dart';

import 'tokens.dart';

class AppColors {
  static const accent = AppTokens.accent;
  static const danger = AppTokens.danger;
}

const appTheme = CupertinoThemeData(primaryColor: AppColors.accent);
