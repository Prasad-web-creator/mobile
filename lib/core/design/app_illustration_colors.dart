import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// `Illustration` collection from Figma (Light / Dark), named
/// material / variant / role. Used only inside illustrations and the hero step
/// tiles: UI chrome stays neutral (design log D21).
@immutable
class AppIllustrationColors extends ThemeExtension<AppIllustrationColors> {
  final Color paperWarmTop;
  final Color paperWarmBottom;
  final Color paperWarmEdge;
  final Color paperWarmLine;
  final Color paperCoolTop;
  final Color paperCoolBottom;
  final Color paperCoolEdge;
  final Color paperCoolLine;
  final Color paperNeutralTop;
  final Color paperNeutralBottom;
  final Color paperNeutralEdge;
  final Color paperNeutralLine;
  final Color accentRedTop;
  final Color accentRedBottom;
  final Color accentBlueTop;
  final Color accentBlueBottom;
  final Color accentNeutralTop;
  final Color accentNeutralBottom;
  final Color effectGloss;
  final Color effectShadow;

  const AppIllustrationColors({
    required this.paperWarmTop,
    required this.paperWarmBottom,
    required this.paperWarmEdge,
    required this.paperWarmLine,
    required this.paperCoolTop,
    required this.paperCoolBottom,
    required this.paperCoolEdge,
    required this.paperCoolLine,
    required this.paperNeutralTop,
    required this.paperNeutralBottom,
    required this.paperNeutralEdge,
    required this.paperNeutralLine,
    required this.accentRedTop,
    required this.accentRedBottom,
    required this.accentBlueTop,
    required this.accentBlueBottom,
    required this.accentNeutralTop,
    required this.accentNeutralBottom,
    required this.effectGloss,
    required this.effectShadow,
  });

  static const AppIllustrationColors light = AppIllustrationColors(
    paperWarmTop: Color(0xFFFFFBEF),
    paperWarmBottom: Color(0xFFFCEBC2),
    paperWarmEdge: Color(0xFFE9C97E),
    paperWarmLine: Color(0xFFEED6A0),
    paperCoolTop: Color(0xFFF3F7FF),
    paperCoolBottom: Color(0xFFD3E0FD),
    paperCoolEdge: Color(0xFFA4BCF8),
    paperCoolLine: Color(0xFFB4C9FB),
    paperNeutralTop: Color(0xFFFFFFFF),
    paperNeutralBottom: Color(0xFFEBEBE8),
    paperNeutralEdge: Color(0xFFC4C7CE),
    paperNeutralLine: Color(0xFFD9D9D9),
    accentRedTop: Color(0xFFF64E4E),
    accentRedBottom: Color(0xFF8E2424),
    accentBlueTop: Color(0xFF4390F5),
    accentBlueBottom: Color(0xFF0C3F81),
    accentNeutralTop: Color(0xFFF4F5F7),
    accentNeutralBottom: Color(0xFFC9CED6),
    effectGloss: Color(0xFFFFFFFF),
    effectShadow: Color(0x0F0B1220), // #0B1220 6%
  );

  static const AppIllustrationColors dark = AppIllustrationColors(
    paperWarmTop: Color(0xFF3D3627),
    paperWarmBottom: Color(0xFF2B261C),
    paperWarmEdge: Color(0xFF6A5530),
    paperWarmLine: Color(0xFF5A4A2C),
    paperCoolTop: Color(0xFF2F3647),
    paperCoolBottom: Color(0xFF222733),
    paperCoolEdge: Color(0xFF46598A),
    paperCoolLine: Color(0xFF3D4A6E),
    paperNeutralTop: Color(0xFF3B3C40),
    paperNeutralBottom: Color(0xFF28292C),
    paperNeutralEdge: Color(0xFF4A4B50),
    paperNeutralLine: Color(0xFF4A4B50),
    accentRedTop: Color(0xFFFF6A6A),
    accentRedBottom: Color(0xFF7A2424),
    accentBlueTop: Color(0xFF6AA2FF),
    accentBlueBottom: Color(0xFF1E4C96),
    accentNeutralTop: Color(0xFFECEEF2),
    accentNeutralBottom: Color(0xFF8A8F9A),
    effectGloss: Color(0xB3FFFFFF), // #FFFFFF 70%
    effectShadow: Color(0x73000000), // #000000 45%
  );

  /// Light hex (as exported in the SVGs) → this theme's value.
  ///
  /// The SVGs only use warm/cool paper, the accents and gloss, so `#FFFFFF`
  /// maps to `effect/gloss` (neutral paper isn't used in any illustration yet).
  Map<int, Color> get svgColorMap => {
    for (final pair in [
      (light.paperWarmTop, paperWarmTop),
      (light.paperWarmBottom, paperWarmBottom),
      (light.paperWarmEdge, paperWarmEdge),
      (light.paperWarmLine, paperWarmLine),
      (light.paperCoolTop, paperCoolTop),
      (light.paperCoolBottom, paperCoolBottom),
      (light.paperCoolEdge, paperCoolEdge),
      (light.paperCoolLine, paperCoolLine),
      (light.accentRedTop, accentRedTop),
      (light.accentRedBottom, accentRedBottom),
      (light.accentBlueTop, accentBlueTop),
      (light.accentBlueBottom, accentBlueBottom),
      (light.accentNeutralTop, accentNeutralTop),
      (light.accentNeutralBottom, accentNeutralBottom),
      (light.effectGloss, effectGloss),
    ])
      pair.$1.toARGB32(): pair.$2,
  };

  @override
  AppIllustrationColors copyWith() => this;

  @override
  AppIllustrationColors lerp(ThemeExtension<AppIllustrationColors>? other, double t) {
    if (other is! AppIllustrationColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Swaps each light-mode hex in an illustration SVG for the current theme's
/// token value (handoff §5.5).
///
/// Equality is by [colors] so flutter_svg's picture cache is reused across
/// rebuilds instead of re-parsing the SVG.
class IllustrationColorMapper extends ColorMapper {
  const IllustrationColorMapper(this.colors);

  final AppIllustrationColors colors;

  static final Map<AppIllustrationColors, Map<int, Color>> _maps = {};

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    final map = _maps.putIfAbsent(colors, () => colors.svgColorMap);
    return map[color.withAlpha(255).toARGB32()] ?? color;
  }

  @override
  bool operator ==(Object other) => other is IllustrationColorMapper && identical(other.colors, colors);

  @override
  int get hashCode => identityHashCode(colors);
}
