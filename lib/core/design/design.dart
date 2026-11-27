/// Policy Pal design system (Figma "Home v4" handoff, Nov 2026).
///
/// Redesigned screens use only these tokens and the `App*` widgets in
/// `lib/core/design/widgets/`. Screens not yet redesigned keep using the older
/// `AppPalette` / `AppSpacing` / `AppRadius` in `lib/core/theme/`.
library;

import 'package:flutter/material.dart';

import 'package:claimsupport/core/design/app_colors.dart';
import 'package:claimsupport/core/design/app_illustration_colors.dart';

export 'package:claimsupport/core/design/app_colors.dart';
export 'package:claimsupport/core/design/app_illustration_colors.dart';
export 'package:claimsupport/core/design/app_metrics.dart';
export 'package:claimsupport/core/design/app_text_styles.dart';

extension DesignContext on BuildContext {
  /// `Colors` tokens for the current theme.
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light);

  /// `Illustration` tokens for the current theme.
  AppIllustrationColors get illustration =>
      Theme.of(this).extension<AppIllustrationColors>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppIllustrationColors.dark : AppIllustrationColors.light);
}
