import 'package:flutter/cupertino.dart';

/// Colors, radii and outlines of the Emerald look (see docs/superpowers/specs/2026-11-11-rebrand-design.md).
/// Every color has a dark and a light value and resolves with `.resolveFrom(context)`.
class AppTokens {
  static const _ink = Color(0xFF0D1F17);
  static const _paper = Color(0xFFF0F5E6);

  static const bg = CupertinoDynamicColor.withBrightness(
    color: _paper,
    darkColor: _ink,
  );
  static const card = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF173326),
  );
  static const tab = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF173326),
  );
  static const text = CupertinoDynamicColor.withBrightness(
    color: _ink,
    darkColor: _paper,
  );
  static const muted = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF45564B),
    darkColor: Color(0xFFA9BBAF),
  );

  /// Brand fill: buttons, the hero, selected states. Text on it is [onAccent].
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF00A86B),
    darkColor: Color(0xFF3FD79B),
  );
  static const onAccent = CupertinoDynamicColor.withBrightness(
    color: _ink,
    darkColor: _ink,
  );

  /// Brand colour for text on a card or on the page: links and income amounts.
  static const accentText = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF00704A),
    darkColor: Color(0xFF3FD79B),
  );

  /// Outlines and hard shadows.
  static const line = CupertinoDynamicColor.withBrightness(
    color: _ink,
    darkColor: _paper,
  );
  static const gold = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFC93C),
    darkColor: Color(0xFFFFC93C),
  );

  /// Text and icons on a light tint (gold, mint, the category colours) in both modes.
  static const onTint = CupertinoDynamicColor.withBrightness(
    color: _ink,
    darkColor: _ink,
  );

  /// Tracks of bars and skeleton blocks.
  static const bar = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFDCE5CC),
    darkColor: Color(0xFF2B4C3D),
  );

  /// Warning pill fill (text on it: [onTint]).
  static const warnBg = gold;

  /// Warning text on a card or on the page.
  static const warnText = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF7A4A00),
    darkColor: Color(0xFFFFC93C),
  );

  /// "Paid" pill fill (text on it: [okText]).
  static const okBg = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF3FD79B),
    darkColor: Color(0xFF3FD79B),
  );
  static const okText = onTint;
  static const income = accentText;
  static const danger = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD11A3F),
    darkColor: Color(0xFFFF9DB0),
  );

  static const double radiusCard = 20;
  static const double radiusHero = 26;
  static const double radiusSheet = 28;
  static const double radiusTile = 13;
  static const double outline = 2.5;
  static const double outlineThin = 2;
}

/// The ink outline every card, button and tile is drawn with.
Border outlineOf(BuildContext context, {double width = AppTokens.outline}) =>
    Border.all(color: AppTokens.line.resolveFrom(context), width: width);

/// The hard offset shadow of the look: no blur, to the right and down in both text directions.
List<BoxShadow> hardShadowOf(
  BuildContext context, {
  Offset offset = const Offset(4, 5),
}) => [BoxShadow(color: AppTokens.line.resolveFrom(context), offset: offset)];
