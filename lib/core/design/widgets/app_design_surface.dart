import 'package:flutter/material.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/theme/app_palette.dart';

/// Keeps Material controls and existing palette-aware content on the same
/// tokens as the Policy Pal shell that hosts them.
class AppDesignSurface extends StatelessWidget {
  const AppDesignSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parent = Theme.of(context);
    final c = context.colors;
    final illustration = context.illustration;
    if (parent.extension<_DesignSurfaceTheme>() != null) return child;
    final text = TextTheme(
      displayLarge: AppTextStyles.largeTitle.copyWith(color: c.textPrimary),
      displayMedium: AppTextStyles.largeTitle.copyWith(color: c.textPrimary),
      displaySmall: AppTextStyles.largeTitle.copyWith(color: c.textPrimary),
      headlineLarge: AppTextStyles.title.copyWith(color: c.textPrimary),
      headlineMedium: AppTextStyles.title.copyWith(color: c.textPrimary),
      headlineSmall: AppTextStyles.title.copyWith(color: c.textPrimary),
      titleLarge: AppTextStyles.headline.copyWith(color: c.textPrimary),
      titleMedium: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
      titleSmall: AppTextStyles.subheadStrong.copyWith(color: c.textPrimary),
      bodyLarge: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
      bodyMedium: AppTextStyles.subheadRegular.copyWith(color: c.textPrimary),
      bodySmall: AppTextStyles.captionRegular.copyWith(color: c.textSecondary),
      labelLarge: AppTextStyles.label.copyWith(color: c.textPrimary),
      labelMedium: AppTextStyles.captionStrong.copyWith(color: c.textSecondary),
      labelSmall: AppTextStyles.microStrong.copyWith(color: c.textSecondary),
    );
    final scheme = ColorScheme(
      brightness: parent.brightness,
      primary: c.buttonPrimary,
      onPrimary: c.textOnButton,
      primaryContainer: c.surfaceSelected,
      onPrimaryContainer: c.textPrimary,
      secondary: c.buttonSecondary,
      onSecondary: c.buttonOnSecondary,
      secondaryContainer: c.surfaceSelected,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.iconActive,
      onTertiary: c.textOnButton,
      tertiaryContainer: c.surfaceSelected,
      onTertiaryContainer: c.textPrimary,
      error: c.statusNotCovered,
      onError: c.surfaceCard,
      errorContainer: c.statusNotCoveredBackground,
      onErrorContainer: c.statusNotCovered,
      surface: c.backgroundPage,
      onSurface: c.textPrimary,
      surfaceDim: c.surfaceCardSubtle,
      surfaceBright: c.backgroundPage,
      surfaceContainerLowest: c.backgroundPage,
      surfaceContainerLow: c.surfaceCard,
      surfaceContainer: c.surfaceCardSubtle,
      surfaceContainerHigh: c.surfaceCardRaised,
      surfaceContainerHighest: c.surfacePressed,
      onSurfaceVariant: c.textSecondary,
      outline: c.borderStrong,
      outlineVariant: c.borderSubtle,
      inversePrimary: c.textLink,
      inverseSurface: c.buttonSecondary,
      onInverseSurface: c.buttonOnSecondary,
      surfaceTint: Colors.transparent,
      shadow: illustration.effectShadow,
    );

    ToneColors tone(Color foreground, Color background) =>
        ToneColors(fg: foreground, bg: background, border: c.borderSubtle);
    final neutral = tone(c.textSecondary, c.surfaceCardSubtle);
    final palette = AppPalette(
      primary: c.buttonPrimary,
      primarySoft: c.surfaceSelected,
      onPrimary: c.textOnButton,
      accent: c.iconActive,
      accentSoft: c.surfaceSelected,
      navy: c.backgroundGradientTop,
      background: c.backgroundPage,
      surface: c.surfaceCard,
      surfaceMuted: c.surfaceCardSubtle,
      border: c.borderSubtle,
      borderStrong: c.borderStrong,
      textPrimary: c.textPrimary,
      textSecondary: c.textSecondary,
      textTertiary: c.textTertiary,
      success: tone(c.statusCovered, c.statusCoveredBackground),
      warning: tone(c.statusPartial, c.statusPartialBackground),
      danger: tone(c.statusNotCovered, c.statusNotCoveredBackground),
      info: tone(c.textLink, c.surfaceSelected),
      verify: neutral,
      neutral: neutral,
      shadow: illustration.effectShadow,
    );
    final theme = ThemeData(
      useMaterial3: true,
      platform: parent.platform,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: c.backgroundPage,
      canvasColor: c.backgroundPage,
      cardColor: c.surfaceCard,
      dividerColor: c.borderSubtle,
      iconTheme: IconThemeData(color: c.iconDefault),
      splashFactory: NoSplash.splashFactory,
      highlightColor: c.surfacePressed,
      extensions: [
        c,
        illustration,
        const _DesignSurfaceTheme(),
        ...parent.extensions.values.where(
          (extension) => extension is! AppPalette && extension is! AppColors && extension is! AppIllustrationColors,
        ),
        palette,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: c.backgroundPage,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.iconDefault),
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(color: c.surfaceCard, shape: DsShape.shape(DsShape.radiusXl)),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceCardRaised,
        modalBackgroundColor: c.surfaceCardRaised,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(DsShape.radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.surfaceCardRaised, shape: DsShape.shape(DsShape.radiusXl)),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceCardRaised,
        contentTextStyle: text.bodyMedium,
        actionTextColor: c.textLink,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(DsShape.radiusMd)),
          borderSide: BorderSide(color: c.borderStrong),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: DefaultTextStyle.merge(style: text.bodyMedium, child: child),
    );
  }
}

class _DesignSurfaceTheme extends ThemeExtension<_DesignSurfaceTheme> {
  const _DesignSurfaceTheme();

  @override
  _DesignSurfaceTheme copyWith() => this;

  @override
  _DesignSurfaceTheme lerp(covariant _DesignSurfaceTheme? other, double t) => this;
}
