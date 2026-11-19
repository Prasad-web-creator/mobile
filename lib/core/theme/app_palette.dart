import 'package:flutter/material.dart';
import 'package:claimsupport/core/theme/app_tokens.dart';

/// Foreground / background / border triple for one semantic tone.
@immutable
class ToneColors {
  final Color fg;
  final Color bg;
  final Color border;

  const ToneColors({required this.fg, required this.bg, required this.border});
}

/// App-wide colour palette, available in both light and dark variants through
/// `context.palette`. Screens read colours from here rather than hard-coding
/// `Color(0x...)` values or branching on `isDark`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  // Brand
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color accent;
  final Color accentSoft;
  final Color navy;

  // Surfaces
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Semantic
  final ToneColors success;
  final ToneColors warning;
  final ToneColors danger;
  final ToneColors info;
  final ToneColors verify;
  final ToneColors neutral;

  final Color shadow;

  const AppPalette({
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.accent,
    required this.accentSoft,
    required this.navy,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.verify,
    required this.neutral,
    required this.shadow,
  });

  static const AppPalette light = AppPalette(
    primary: Color(0xFF1D4ED8),
    primarySoft: Color(0xFFEFF4FF),
    onPrimary: Colors.white,
    accent: Color(0xFF0F766E),
    accentSoft: Color(0xFFE6F4F2),
    navy: Color(0xFF0B2545),
    background: Color(0xFFF5F7FA),
    surface: Colors.white,
    surfaceMuted: Color(0xFFF1F4F8),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF64748B),
    success: ToneColors(fg: Color(0xFF047857), bg: Color(0xFFECFDF5), border: Color(0xFFA7F3D0)),
    warning: ToneColors(fg: Color(0xFFB45309), bg: Color(0xFFFFFBEB), border: Color(0xFFFDE68A)),
    danger: ToneColors(fg: Color(0xFFB91C1C), bg: Color(0xFFFEF2F2), border: Color(0xFFFECACA)),
    info: ToneColors(fg: Color(0xFF1D4ED8), bg: Color(0xFFEFF4FF), border: Color(0xFFBFDBFE)),
    verify: ToneColors(fg: Color(0xFF6D28D9), bg: Color(0xFFF5F3FF), border: Color(0xFFDDD6FE)),
    neutral: ToneColors(fg: Color(0xFF475569), bg: Color(0xFFF1F5F9), border: Color(0xFFE2E8F0)),
    shadow: Color(0x0F0F172A),
  );

  static const AppPalette dark = AppPalette(
    primary: Color(0xFF6B9BFF),
    primarySoft: Color(0xFF16264A),
    onPrimary: Color(0xFF0B1220),
    accent: Color(0xFF2DD4BF),
    accentSoft: Color(0xFF0F2E2C),
    navy: Color(0xFF0E1F3D),
    background: Color(0xFF0B1220),
    surface: Color(0xFF121B2D),
    surfaceMuted: Color(0xFF18233A),
    border: Color(0xFF243149),
    borderStrong: Color(0xFF33425E),
    textPrimary: Color(0xFFE8EDF5),
    textSecondary: Color(0xFFA5B1C4),
    textTertiary: Color(0xFF8391A7),
    success: ToneColors(fg: Color(0xFF34D399), bg: Color(0xFF0C2A22), border: Color(0xFF14532D)),
    warning: ToneColors(fg: Color(0xFFFBBF24), bg: Color(0xFF2B2110), border: Color(0xFF713F12)),
    danger: ToneColors(fg: Color(0xFFF87171), bg: Color(0xFF2D1518), border: Color(0xFF7F1D1D)),
    info: ToneColors(fg: Color(0xFF93B4FF), bg: Color(0xFF16264A), border: Color(0xFF1E3A8A)),
    verify: ToneColors(fg: Color(0xFFC4B5FD), bg: Color(0xFF221A3D), border: Color(0xFF4C1D95)),
    neutral: ToneColors(fg: Color(0xFFA5B1C4), bg: Color(0xFF18233A), border: Color(0xFF243149)),
    shadow: Color(0x40000000),
  );

  ToneColors tone(AppTone tone) {
    switch (tone) {
      case AppTone.success:
        return success;
      case AppTone.warning:
        return warning;
      case AppTone.danger:
        return danger;
      case AppTone.info:
        return info;
      case AppTone.verify:
        return verify;
      case AppTone.brand:
        return ToneColors(fg: primary, bg: primarySoft, border: primary.withAlpha(60));
      case AppTone.neutral:
        return neutral;
    }
  }

  /// Subtle elevation used by cards that need lift (most cards use only a border).
  List<BoxShadow> get softShadow => [BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 4))];

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppPaletteContext on BuildContext {
  /// Current app palette (light or dark).
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  TextTheme get text => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
