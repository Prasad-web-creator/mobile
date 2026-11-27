import 'package:flutter/widgets.dart';

/// Figma text styles (Typography collection), Geist. Colours are applied
/// separately from [AppColors]; these styles carry no colour.
///
/// Figma tracking is a percentage of the font size; Flutter's letterSpacing is
/// in logical pixels, hence `size * pct`.
class AppTextStyles {
  AppTextStyles._();

  static const String sans = 'Geist';
  static const String mono = 'GeistMono';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static TextStyle _style(double size, double lineHeight, FontWeight weight, {double trackingPct = 0}) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: size * trackingPct,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// 34/40 SemiBold −2.5% — Home title, screen titles.
  static final TextStyle largeTitle = _style(34, 40, semibold, trackingPct: -0.025);

  /// 30/36 SemiBold −2% — counts on document cards. Tabular figures.
  static final TextStyle numberCount = _style(
    30,
    36,
    semibold,
    trackingPct: -0.02,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// 22/28 SemiBold −1.5% — status label ("Fully covered").
  static final TextStyle title = _style(22, 28, semibold, trackingPct: -0.015);

  /// 17/22 SemiBold — section titles, card titles, full-width button labels.
  static final TextStyle headline = _style(17, 22, semibold);

  static final TextStyle reportBody = _style(15, 22, regular);
  static final TextStyle rowTitle = _style(16, 22, semibold);
  static final TextStyle checkStatus = _style(20, 26, semibold, trackingPct: -0.01);
  static final TextStyle compactStatus = _style(14, 18, semibold);
  static final TextStyle secondary = _style(14, 20, regular);
  static final TextStyle chip = _style(12, 16, semibold);

  /// 16/22 Medium — step labels.
  static final TextStyle bodyStrong = _style(16, 22, medium);

  /// 15/20 Medium — greeting.
  static final TextStyle subheadRegular = _style(15, 20, medium);

  /// 15/20 SemiBold — small card titles, compact button labels (New check).
  static final TextStyle subheadStrong = _style(15, 20, semibold);

  /// 14/18 Medium — chips.
  static final TextStyle label = _style(14, 18, medium);

  /// 13/18 Regular — meta, dates.
  static final TextStyle captionRegular = _style(13, 18, regular);

  /// 13/18 SemiBold — avatar initials, "You pay ₹0".
  static final TextStyle captionStrong = _style(13, 18, semibold);

  /// 11/14 Medium — tab labels.
  static final TextStyle microRegular = _style(11, 14, medium);

  /// 11/14 SemiBold — selected tab label.
  static final TextStyle microStrong = _style(11, 14, semibold);
}
