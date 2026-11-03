import 'package:flutter/cupertino.dart';

/// Colors, radii and spacing of the redesigned look (see docs/superpowers/specs/2026-11-03-home-redesign-design.md).
/// Every color has a dark and a light value and resolves with `.resolveFrom(context)`.
class AppTokens {
  static const bg = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF3F5F8),
    darkColor: Color(0xFF0B0F14),
  );
  static const card = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF141A22),
  );
  static const tab = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1B232D),
  );
  static const text = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0F172A),
    darkColor: Color(0xFFF2F5F7),
  );
  static const muted = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF5B6B80),
    darkColor: Color(0xFF8B97A5),
  );
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0A7E6B),
    darkColor: Color(0xFF3CC4A8),
  );
  static const onAccent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF06241E),
  );
  static const bar = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD9E0E8),
    darkColor: Color(0xFF2A3542),
  );
  static const heroFrom = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0A8F78),
    darkColor: Color(0xFF0E9C82),
  );
  static const heroTo = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0B5666),
    darkColor: Color(0xFF0A4D5C),
  );
  static const warnBg = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFF1DB),
    darkColor: Color(0xFF3A2C14),
  );
  static const warnText = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8A5200),
    darkColor: Color(0xFFFFB340),
  );
  static const okBg = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFDDF3EE),
    darkColor: Color(0xFF143A33),
  );
  static const okText = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0A6455),
    darkColor: Color(0xFF3CC4A8),
  );
  static const income = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1E8E3E),
    darkColor: Color(0xFF4CD07A),
  );
  static const danger = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC5221F),
    darkColor: Color(0xFFFF6B66),
  );

  static const double radiusCard = 24;
  static const double radiusHero = 28;
}
