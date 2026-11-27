import 'package:flutter/widgets.dart';

/// `Spacing` collection: `space/*` scale plus `layout/*` aliases.
class DsSpace {
  DsSpace._();

  static const double s0 = 0;
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  /// layout/screen-padding — left/right screen padding.
  static const double screenPadding = s20;

  /// layout/section-gap — between sections.
  static const double sectionGap = s24;

  /// layout/card-padding — inside cards.
  static const double cardPadding = s16;

  /// layout/grid-gap — between cards.
  static const double gridGap = s12;

  /// layout/screen-top: safe area + 8 (62 in Figma on a 54pt status bar).
  static double screenTop(BuildContext context) => MediaQuery.paddingOf(context).top + s8;
}

/// `Shape` collection. Use with continuous corners ([RoundedSuperellipseBorder]).
class DsShape {
  DsShape._();

  static const double radiusXs = 6; // tags
  static const double radiusSm = 10; // icon tiles
  static const double radiusMd = 14; // inputs
  static const double radiusLg = 20;
  static const double radiusXl = 24; // cards
  static const double radiusFull = 999; // pills, avatar, nav, round buttons

  static const double strokeHairline = 0.5; // glass edges
  static const double strokeDefault = 1; // borders

  /// Continuous-corner shape with an optional border.
  static RoundedSuperellipseBorder shape(double radius, {BorderSide side = BorderSide.none}) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(radius)), side: side);
}

/// `Size` collection.
class DsSize {
  DsSize._();

  static const double iconXs = 14; // chip caret
  static const double iconSm = 16; // + icon
  static const double iconMd = 18; // step tile icons
  static const double iconLg = 20; // New check icon
  static const double iconXl = 22; // tab icons

  static const double controlSm = 32; // icon tiles, round add buttons (in a 44 hit area)
  static const double controlMd = 36; // chips
  static const double controlLg = 44; // minimum touch target
  static const double controlXl = 54; // full-width primary buttons
  static const double control2xl = 60; // floating nav bar, New check button

  static const double avatarMd = 40;
  static const double tabHeight = 52;
  static const double indicatorDot = 10;

  // Values specified by the handoff for the Home check stack and document art.
  static const double stackPeek = 11;
  static const double stackInset = 14;
  static const double documentCardAspect = 175 / 164;
  static const double prescriptionArtRight = -22;
  static const double policyArtRight = -29;
  static const double documentArtBottom = -53;

  /// Home background height (handoff §4.4b).
  static const double homeBackgroundHeight = 460;
  static const double authBackgroundHeight = 300;
}

/// Motion tokens (handoff §5.7). Respect Reduce Motion via [DsMotion.reduced].
class DsMotion {
  DsMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Curve fastCurve = Curves.easeOut;

  static const Duration base = Duration(milliseconds: 200);
  static const Curve baseCurve = Curves.easeOutCubic;

  static const Duration slow = Duration(milliseconds: 320);
  static const Curve slowCurve = Cubic(0.2, 0, 0, 1);

  static const SpringDescription spring = SpringDescription(mass: 1, stiffness: 400, damping: 30);

  static const double pressScale = 0.97;
  static const double stackExitScale = 0.94;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

class DsEffect {
  DsEffect._();

  static BoxShadow checkStackShadow({required double lift, BlurStyle blurStyle = BlurStyle.normal}) =>
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.06 + 0.02 * lift),
        offset: Offset(0, 4 + 2 * lift),
        blurRadius: 16 + 4 * lift,
        blurStyle: blurStyle,
      );

  static const double glassBlur = 20;
  static const double checkCardBlur = 24;
  static const double avatarBlur = 10;
  static const double navBlur = 24;
}
