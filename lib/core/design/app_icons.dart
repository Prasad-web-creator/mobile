import 'package:flutter/widgets.dart';

/// Phosphor icons (MIT, see assets/fonts/phosphor/LICENSE.txt), bundled as
/// fonts. Regular weight by default; Fill only in the hero steps and the active
/// tab (design log D23, D24).
///
/// The `phosphor_flutter` package (2.1.0, latest) doesn't compile on Flutter
/// 3.50+ because `IconData` is now a final class, so the two font files and the
/// codepoints we use are bundled here instead. Add icons as screens need them;
/// codepoints come from phosphor_flutter's `phosphor_icons_regular.dart`.
class AppIcons {
  AppIcons._();

  static const _regular = 'PhosphorRegular';
  static const _fill = 'PhosphorFill';

  // Regular
  static const IconData house = IconData(0xe2c2, fontFamily: _regular);
  static const IconData history = IconData(0xe1a0, fontFamily: _regular);
  static const IconData caretLeft = IconData(0xe138, fontFamily: _regular, matchTextDirection: true);
  static const IconData caretRight = IconData(0xe13a, fontFamily: _regular, matchTextDirection: true);
  static const IconData share = IconData(0xe406, fontFamily: _regular);
  static const IconData listChecks = IconData(0xeadc, fontFamily: _regular);
  static const IconData trash = IconData(0xe4a6, fontFamily: _regular);
  static const IconData info = IconData(0xe2ce, fontFamily: _regular);
  static const IconData warningCircle = IconData(0xe4e2, fontFamily: _regular);
  static const IconData hourglassMedium = IconData(0xe2b8, fontFamily: _regular);
  static const IconData arrowClockwise = IconData(0xe036, fontFamily: _regular);
  static const IconData warning = IconData(0xe4e0, fontFamily: _regular);
  static const IconData wifiSlash = IconData(0xe4f2, fontFamily: _regular);
  static const IconData fileText = IconData(0xe23a, fontFamily: _regular);
  static const IconData close = IconData(0xe4f6, fontFamily: _regular);
  static const IconData scan = IconData(0xebb6, fontFamily: _regular);
  static const IconData plus = IconData(0xe3d4, fontFamily: _regular);
  static const IconData pencil = IconData(0xebc6, fontFamily: _regular);
  static const IconData appearance = IconData(0xe18c, fontFamily: _regular);
  static const IconData bell = IconData(0xe0ce, fontFamily: _regular);
  static const IconData help = IconData(0xe3e8, fontFamily: _regular);
  static const IconData lock = IconData(0xe308, fontFamily: _regular);
  static const IconData signOut = IconData(0xe42a, fontFamily: _regular);
  static const IconData caretDown = IconData(0xe136, fontFamily: _regular);
  static const IconData user = IconData(0xe4c2, fontFamily: _regular);

  // Fill
  static const IconData houseFill = IconData(0xe2c2, fontFamily: _fill);
  static const IconData historyFill = IconData(0xe1a0, fontFamily: _fill);
  static const IconData pillFill = IconData(0xe700, fontFamily: _fill);
  static const IconData shieldCheckFill = IconData(0xe40c, fontFamily: _fill);
  static const IconData currencyInrFill = IconData(0xe558, fontFamily: _fill);
}
