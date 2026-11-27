import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:claimsupport/core/theme/app_palette.dart';
import 'package:claimsupport/core/theme/app_tokens.dart';
import 'package:claimsupport/core/design/app_colors.dart';
import 'package:claimsupport/core/design/app_illustration_colors.dart';

export 'package:claimsupport/core/theme/app_palette.dart';
export 'package:claimsupport/core/theme/app_tokens.dart';

/// Centralized string constants for SharedPreferences keys
/// and other app-wide values.
class AppConstants {
  // SharedPreferences keys
  static const String kAuthTokenKey = 'auth_token';
  static const String kRefreshTokenKey = 'refresh_token';
  static const String kPrescriptionPathKey = 'prescription_path';
  static const String kPolicyPathKey = 'policy_path';
  static const String kAnalysisResultKey = 'analysis_result';
  static const String kThemeModeKey = 'theme_mode';
}

class AppTheme {
  static ThemeData get lightTheme => _build(AppPalette.light, Brightness.light);
  static ThemeData get darkTheme => _build(AppPalette.dark, Brightness.dark);

  static TextTheme _textTheme(AppPalette p, Brightness b) {
    final base = b == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final inter = GoogleFonts.interTextTheme(base);
    TextStyle s(TextStyle? t, double size, FontWeight w, Color c, {double h = 1.3, double ls = 0}) =>
        (t ?? const TextStyle()).copyWith(fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls);

    return inter.copyWith(
      displaySmall: s(inter.displaySmall, 30, FontWeight.w700, p.textPrimary, h: 1.2, ls: -0.5),
      headlineMedium: s(inter.headlineMedium, 26, FontWeight.w700, p.textPrimary, h: 1.25, ls: -0.4),
      headlineSmall: s(inter.headlineSmall, 22, FontWeight.w700, p.textPrimary, h: 1.27, ls: -0.3),
      titleLarge: s(inter.titleLarge, 18, FontWeight.w700, p.textPrimary, h: 1.33, ls: -0.2),
      titleMedium: s(inter.titleMedium, 16, FontWeight.w600, p.textPrimary, h: 1.4),
      titleSmall: s(inter.titleSmall, 14, FontWeight.w600, p.textPrimary, h: 1.4),
      bodyLarge: s(inter.bodyLarge, 15, FontWeight.w400, p.textPrimary, h: 1.5),
      bodyMedium: s(inter.bodyMedium, 14, FontWeight.w400, p.textSecondary, h: 1.5),
      bodySmall: s(inter.bodySmall, 12.5, FontWeight.w400, p.textTertiary, h: 1.45),
      labelLarge: s(inter.labelLarge, 15, FontWeight.w600, p.textPrimary, h: 1.2),
      labelMedium: s(inter.labelMedium, 12.5, FontWeight.w600, p.textSecondary, h: 1.3),
      labelSmall: s(inter.labelSmall, 11, FontWeight.w600, p.textTertiary, h: 1.3, ls: 0.6),
    );
  }

  static ThemeData _build(AppPalette p, Brightness b) {
    final isDark = b == Brightness.dark;
    final text = _textTheme(p, b);

    final scheme = ColorScheme(
      brightness: b,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.primary,
      secondary: p.accent,
      onSecondary: Colors.white,
      secondaryContainer: p.accentSoft,
      onSecondaryContainer: p.accent,
      tertiary: p.verify.fg,
      onTertiary: Colors.white,
      error: p.danger.fg,
      onError: Colors.white,
      errorContainer: p.danger.bg,
      onErrorContainer: p.danger.fg,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceMuted,
      surfaceContainerHigh: p.surfaceMuted,
      surfaceContainerHighest: p.surfaceMuted,
      outline: p.borderStrong,
      outlineVariant: p.border,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: isDark ? const Color(0xFFE8EDF5) : const Color(0xFF0F172A),
      onInverseSurface: isDark ? const Color(0xFF0F172A) : Colors.white,
      inversePrimary: isDark ? const Color(0xFF1D4ED8) : const Color(0xFF93B4FF),
      surfaceTint: Colors.transparent,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide(color: p.border),
    );

    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);
    const buttonMinSize = Size(64, 52);
    final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: null);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      textTheme: text,
      primaryColor: p.primary,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      cardColor: p.surface,
      dividerColor: p.border,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: [
        p,
        isDark ? AppColors.dark : AppColors.light,
        isDark ? AppIllustrationColors.dark : AppIllustrationColors.light,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        iconTheme: IconThemeData(color: p.textPrimary, size: 24),
        actionsIconTheme: IconThemeData(color: p.textSecondary, size: 24),
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.primary.withAlpha(90),
          disabledForegroundColor: p.onPrimary.withAlpha(220),
          elevation: 0,
          minimumSize: buttonMinSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.primary.withAlpha(90),
          disabledForegroundColor: p.onPrimary.withAlpha(220),
          minimumSize: buttonMinSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: buttonMinSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
          side: BorderSide(color: p.borderStrong),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: buttonShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: null),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.textPrimary, minimumSize: const Size(44, 44)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        hintStyle: text.bodyMedium?.copyWith(color: p.textTertiary.withAlpha(200)),
        labelStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: p.primary, fontWeight: FontWeight.w600),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: p.danger.fg),
        prefixIconColor: p.textTertiary,
        suffixIconColor: p.textTertiary,
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.border.withAlpha(120))),
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.primary, width: 1.6)),
        errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.danger.fg)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.danger.fg, width: 1.6)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceMuted,
        selectedColor: p.primarySoft,
        side: BorderSide(color: p.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        showDragHandle: true,
        dragHandleColor: p.borderStrong,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1E2A40) : const Color(0xFF0F172A),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: const Color(0xFF93B4FF),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        insetPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minVerticalPadding: AppSpacing.sm,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.primarySoft,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
        side: BorderSide(color: p.borderStrong, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(p.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.borderStrong,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : p.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.borderStrong,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.textTertiary,
        indicatorColor: p.primary,
        dividerColor: p.border,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: p.border),
        ),
        textStyle: text.bodyMedium?.copyWith(color: p.textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2A40) : const Color(0xFF0F172A),
          borderRadius: AppRadius.smAll,
        ),
        textStyle: text.bodySmall?.copyWith(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: p.primarySoft,
        indicatorShape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? p.primary : p.textTertiary),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected) ? p.primary : p.textTertiary,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyLarge,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll,
              side: BorderSide(color: p.border),
            ),
          ),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.textSecondary,
        collapsedIconColor: p.textTertiary,
        textColor: p.textPrimary,
        collapsedTextColor: p.textPrimary,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
    );
  }
}
