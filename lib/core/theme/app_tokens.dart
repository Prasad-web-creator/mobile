import 'package:flutter/material.dart';

/// Spacing scale (4-pt grid). Use these instead of ad-hoc numbers so every
/// screen shares the same rhythm.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Horizontal page gutter used by every screen.
  static const double page = 20;

  /// Gap between major sections on a screen.
  static const double section = 24;

  /// Standard page padding (top/bottom handled by each screen).
  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(page, md, page, xxl);

  /// Max content width so tablets / large phones don't stretch cards edge-to-edge.
  static const double maxContentWidth = 720;
}

/// Corner radii.
class AppRadius {
  AppRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Semantic tone used by badges, banners and coverage status presentation.
enum AppTone { neutral, info, success, warning, danger, verify, brand }
