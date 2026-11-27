import 'package:flutter/material.dart';

/// `Colors` collection from Figma (Policy Pal, page "Home v4"), Light / Dark.
///
/// Names mirror the Figma tokens 1:1 in camelCase (`text/secondary` →
/// `textSecondary`). Values are exact; never hardcode a dark colour, switch the
/// theme instead. Only tokens an agreed screen needs exist (design log D18).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  // background/*
  final Color backgroundPage;
  final Color backgroundHome;
  final Color backgroundGradientTop;
  final Color backgroundGradientMiddle;
  final Color backgroundGradientBottom;

  // surface/*
  final Color surfaceCard;
  final Color surfaceCardRaised;
  final Color surfaceCardSubtle;
  final Color surfacePressed;
  final Color surfaceSelected;
  final Color surfaceStack1;
  final Color surfaceStack2;
  final Color surfaceGlass;
  final Color surfaceCheckGlassTop;
  final Color surfaceNavBar;

  // text/*
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnGradient;
  final Color textOnButton;
  final Color textLink;
  final Color textCheckGlassPrimary;
  final Color textCheckGlassSecondary;

  // border/*
  final Color borderSubtle;
  final Color borderDivider;
  final Color borderStrong;
  final Color borderGlass;
  final Color borderCheckGlass;

  // button/*
  final Color buttonPrimary;
  final Color buttonPrimaryPressed;
  final Color buttonSecondary;
  final Color buttonOnSecondary;
  final Color buttonDisabled;

  // icon/*
  final Color iconDefault;
  final Color iconActive;

  // status/*
  final Color statusCovered;
  final Color statusCheckGlassCovered;
  final Color statusCoveredBackground;
  final Color statusPartial;
  final Color statusPartialDot;
  final Color statusPartialBackground;
  final Color statusNotCovered;
  final Color statusNotCoveredBackground;

  const AppColors({
    required this.backgroundPage,
    required this.backgroundHome,
    required this.backgroundGradientTop,
    required this.backgroundGradientMiddle,
    required this.backgroundGradientBottom,
    required this.surfaceCard,
    required this.surfaceCardRaised,
    required this.surfaceCardSubtle,
    required this.surfacePressed,
    required this.surfaceSelected,
    required this.surfaceStack1,
    required this.surfaceStack2,
    required this.surfaceGlass,
    required this.surfaceCheckGlassTop,
    required this.surfaceNavBar,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnGradient,
    required this.textOnButton,
    required this.textLink,
    required this.textCheckGlassPrimary,
    required this.textCheckGlassSecondary,
    required this.borderSubtle,
    required this.borderDivider,
    required this.borderStrong,
    required this.borderGlass,
    required this.borderCheckGlass,
    required this.buttonPrimary,
    required this.buttonPrimaryPressed,
    required this.buttonSecondary,
    required this.buttonOnSecondary,
    required this.buttonDisabled,
    required this.iconDefault,
    required this.iconActive,
    required this.statusCovered,
    required this.statusCheckGlassCovered,
    required this.statusCoveredBackground,
    required this.statusPartial,
    required this.statusPartialDot,
    required this.statusPartialBackground,
    required this.statusNotCovered,
    required this.statusNotCoveredBackground,
  });

  static const AppColors light = AppColors(
    backgroundPage: Color(0xFFF3F4F6),
    backgroundHome: Color(0xFFFFFFFF),
    backgroundGradientTop: Color(0xFFB4C9FB),
    backgroundGradientMiddle: Color(0xFFC9D7FD),
    backgroundGradientBottom: Color(0xFFF0F4FF),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceCardRaised: Color(0xFFFFFFFF),
    surfaceCardSubtle: Color(0xFFF4F6FA),
    surfacePressed: Color(0xFFEEF0F4),
    surfaceSelected: Color(0xFFE3EAFE),
    surfaceStack1: Color(0xB3FFFFFF), // #FFFFFF 70%
    surfaceStack2: Color(0x73FFFFFF), // #FFFFFF 45%
    surfaceGlass: Color(0x38FFFFFF), // #FFFFFF 22%
    surfaceCheckGlassTop: Color(0x2EFFFFFF),
    surfaceNavBar: Color(0xBFFFFFFF), // #FFFFFF 75%
    textPrimary: Color(0xFF0D0D0E),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF8A8F9A),
    textOnGradient: Color(0xFF0D0D0E),
    textOnButton: Color(0xFFFFFFFF),
    textLink: Color(0xFF2F5BF5),
    textCheckGlassPrimary: Color(0xFF0B1220),
    textCheckGlassSecondary: Color(0xFF5B6272),
    borderSubtle: Color(0xFFE3E5EA),
    borderDivider: Color(0xFFE3E5EA),
    borderStrong: Color(0xFFC4C7CE),
    borderGlass: Color(0x73FFFFFF), // #FFFFFF 45%
    borderCheckGlass: Color(0xE6FFFFFF),
    buttonPrimary: Color(0xFF2F5BF5),
    buttonPrimaryPressed: Color(0xFF2247CF),
    buttonSecondary: Color(0xFF0D0D0E),
    buttonOnSecondary: Color(0xFFFFFFFF),
    buttonDisabled: Color(0xFFE3E5EA),
    iconDefault: Color(0xFF3A3B3F),
    iconActive: Color(0xFF2F5BF5),
    statusCovered: Color(0xFF1C7A4D),
    statusCheckGlassCovered: Color(0xFF1C7A4D),
    statusCoveredBackground: Color(0xFFE3F4EA),
    statusPartial: Color(0xFF9A5300),
    statusPartialDot: Color(0xFFE8862A),
    statusPartialBackground: Color(0xFFFFEBD2),
    statusNotCovered: Color(0xFFB5372A),
    statusNotCoveredBackground: Color(0xFFFDE6E2),
  );

  static const AppColors dark = AppColors(
    backgroundPage: Color(0xFF101011),
    backgroundHome: Color(0xFF0D0D0E),
    backgroundGradientTop: Color(0xFF172C70),
    backgroundGradientMiddle: Color(0xFF141B33),
    backgroundGradientBottom: Color(0xFF101011),
    surfaceCard: Color(0xFF1C1C1F),
    surfaceCardRaised: Color(0xFF26272A),
    surfaceCardSubtle: Color(0xFF1C1C1F),
    surfacePressed: Color(0xFF26272A),
    surfaceSelected: Color(0xFF3A3B3F),
    surfaceStack1: Color(0xFF18181B),
    surfaceStack2: Color(0xFF131315),
    surfaceGlass: Color(0x1AFFFFFF), // #FFFFFF 10%
    surfaceCheckGlassTop: Color(0x331C1C1F),
    surfaceNavBar: Color(0xCC1C1C1F), // #1C1C1F 80%
    textPrimary: Color(0xFFF4F6FA),
    textSecondary: Color(0xFFA3A9B5),
    textTertiary: Color(0xFF8A8F9A),
    textOnGradient: Color(0xFFF4F6FA),
    textOnButton: Color(0xFFFFFFFF),
    textLink: Color(0xFF7A9CF7),
    textCheckGlassPrimary: Color(0xFFF4F6FA),
    textCheckGlassSecondary: Color(0xFFA3A9B5),
    borderSubtle: Color(0xFF26272A),
    borderDivider: Color(0xFF3A3B3F),
    borderStrong: Color(0xFF4A4B50),
    borderGlass: Color(0x26FFFFFF), // #FFFFFF 15%
    borderCheckGlass: Color(0x26FFFFFF),
    buttonPrimary: Color(0xFF2F5BF5),
    buttonPrimaryPressed: Color(0xFF2247CF),
    buttonSecondary: Color(0xFFF4F6FA),
    buttonOnSecondary: Color(0xFF0D0D0E),
    buttonDisabled: Color(0xFF26272A),
    iconDefault: Color(0xFFC4C7CE),
    iconActive: Color(0xFF7A9CF7),
    statusCovered: Color(0xFF4FB57D),
    statusCheckGlassCovered: Color(0xFF2A9A5F),
    statusCoveredBackground: Color(0xFF0B3320),
    statusPartial: Color(0xFFF7B56A),
    statusPartialDot: Color(0xFFEF9C45),
    statusPartialBackground: Color(0xFF382810),
    statusNotCovered: Color(0xFFE66B59),
    statusNotCoveredBackground: Color(0xFF4A1611),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}
