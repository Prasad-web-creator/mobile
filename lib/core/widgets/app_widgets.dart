import 'package:claimsupport/core/localization/localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:claimsupport/core/theme/app_palette.dart';
import 'package:claimsupport/core/theme/app_tokens.dart';
import 'package:claimsupport/core/config/env_config.dart';
import 'package:claimsupport/core/network/server_error_message.dart';

export 'package:claimsupport/core/theme/app_palette.dart';
export 'package:claimsupport/core/theme/app_tokens.dart';
export 'package:claimsupport/core/widgets/coverage_status.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layout
// ─────────────────────────────────────────────────────────────────────────────

/// Centres content and caps its width on large screens.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentWidth({super.key, required this.child, this.maxWidth = AppSpacing.maxContentWidth});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Bordered surface card used for every grouped block of content.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final BorderRadius borderRadius;
  final bool elevated;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.borderColor,
    this.borderRadius = AppRadius.lgAll,
    this.elevated = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? p.border),
        boxShadow: elevated ? p.softShadow : null,
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
            ),
    );
  }
}

/// Section title with optional supporting text and trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.sm),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor ?? p.primary),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Card title row: icon tile + title (+ optional trailing widget).
class CardTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final AppTone tone;
  final String? subtitle;
  final Widget? trailing;

  const CardTitle({
    super.key,
    required this.title,
    required this.icon,
    this.tone = AppTone.brand,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconTile(icon: icon, tone: tone, size: 36),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleMedium),
              if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: context.text.bodySmall),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.xs), trailing!],
      ],
    );
  }
}

/// Rounded-square icon container tinted with a semantic tone.
class IconTile extends StatelessWidget {
  final IconData icon;
  final AppTone tone;
  final double size;
  final Color? color;

  const IconTile({super.key, required this.icon, this.tone = AppTone.brand, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.palette.tone(tone);
    final fg = color ?? t.fg;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color != null ? color!.withAlpha(context.isDark ? 45 : 26) : t.bg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: fg, size: size * 0.52),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status & feedback
// ─────────────────────────────────────────────────────────────────────────────

/// Pill badge with icon + label, so status is never conveyed by colour alone.
class StatusBadge extends StatelessWidget {
  final String label;
  final AppTone tone;
  final IconData? icon;
  final bool dense;

  const StatusBadge({super.key, required this.label, required this.tone, this.icon, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final t = context.palette.tone(tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: t.fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: t.fg,
                fontWeight: FontWeight.w700,
                fontSize: dense ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline message box for disclaimers, warnings, errors and tips.
class InfoBanner extends StatelessWidget {
  final AppTone tone;
  final String? title;
  final String? message;
  final Widget? child;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  const InfoBanner({
    super.key,
    this.tone = AppTone.info,
    this.title,
    this.message,
    this.child,
    this.icon,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  IconData get _defaultIcon {
    switch (tone) {
      case AppTone.success:
        return Icons.check_circle_outline_rounded;
      case AppTone.warning:
        return Icons.warning_amber_rounded;
      case AppTone.danger:
        return Icons.error_outline_rounded;
      case AppTone.verify:
        return Icons.fact_check_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = p.tone(tone);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _defaultIcon, color: t.fg, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty)
                  Text(
                    title!,
                    style: context.text.titleSmall?.copyWith(color: t.fg, fontWeight: FontWeight.w700),
                  ),
                if (title != null && title!.isNotEmpty && (message != null || child != null)) const SizedBox(height: 4),
                if (message != null && message!.isNotEmpty)
                  Text(message!, style: context.text.bodyMedium?.copyWith(color: p.textPrimary.withAlpha(220))),
                ?child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered loading indicator with an optional caption.
class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6)),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(message!, textAlign: TextAlign.center, style: context.text.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly empty state: icon, title, explanation and optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: compact ? AppSpacing.lg : AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 52 : 64,
              height: compact ? 52 : 64,
              decoration: BoxDecoration(color: p.surfaceMuted, shape: BoxShape.circle),
              child: Icon(icon, size: compact ? 24 : 30, color: p.textTertiary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, textAlign: TextAlign.center, style: context.text.titleMedium),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(message!, textAlign: TextAlign.center, style: context.text.bodyMedium),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry action. Shows a readable message, never a raw stack trace.
class ErrorState extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  const ErrorState({super.key, this.title, this.message, this.onRetry, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: title ?? context.l10n.sharedSorryError,
      message: message ?? context.l10n.sharedLoadFailed,
      compact: compact,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.sharedTryAgain),
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
            ),
    );
  }
}

/// Turns an exception into a short, user-facing sentence.
String friendlyErrorMessage(Object? error, {AppLocalizations? l10n}) {
  final serverMessage = serverErrorMessage(error, l10n: l10n);
  if (serverMessage != null) return serverMessage;
  if (l10n != null && l10n.localeName == 'ta') return localizedRequestError(error, l10n);
  final text = (error ?? '').toString();
  final lower = text.toLowerCase();
  if (lower.contains('could not reach the local backend') ||
      (!EnvConfig.isProd && (lower.contains('socket') || lower.contains('connection error')))) {
    return 'Could not reach the local backend. Check its address and confirm it is running.';
  }
  if (lower.contains('socket') || lower.contains('connection') || lower.contains('network')) {
    return 'Could not reach the backend. Please try again.';
  }
  if (lower.contains('timeout')) return 'The server took too long to respond. Please try again.';
  if (lower.contains('401') || lower.contains('unauthor')) return 'Your session has expired. Please sign in again.';
  final cleaned = text.replaceFirst(RegExp(r'^(Exception|AppException|DioException[^:]*):\s*'), '');
  if (cleaned.isEmpty || cleaned.toLowerCase() == 'unknown error' || cleaned.length > 160) {
    return 'We couldn\'t load this information. Please try again.';
  }
  return cleaned;
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────

/// Full-width primary action with built-in loading state.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.onPrimary))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: AppSpacing.xs)],
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ),
            ],
          );
    final button = FilledButton(onPressed: loading ? null : onPressed, child: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Full-width secondary (outlined) action.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? OutlinedButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label));
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Standard confirmation dialog. Returns true when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final p = ctx.palette;
      final tone = destructive ? p.danger : p.info;
      return AlertDialog(
        icon: icon == null
            ? null
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
                child: Icon(icon, color: tone.fg),
              ),
        title: Text(title, textAlign: icon == null ? TextAlign.start : TextAlign.center),
        content: Text(message, textAlign: icon == null ? TextAlign.start : TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                  child: Text(cancelLabel ?? ctx.l10n.sharedCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    backgroundColor: destructive ? p.danger.fg : p.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(confirmLabel ?? ctx.l10n.sharedConfirm),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Unified notification manager: displays a non-overlapping floating banner at the top of the screen.
/// Avoids covering bottom action bars, bottom navigation bars, and inputs.
class AppNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Shows a top-floating notification banner. Replaces any active notification to prevent stacking.
  static void show(
    BuildContext context, {
    required String message,
    AppTone tone = AppTone.neutral,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    hide();

    final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay ?? Overlay.maybeOf(context);
    if (overlay == null) {
      // Fallback to scaffold messenger if overlay is not available
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (ctx) => _AppNotificationBanner(
        message: message,
        tone: tone,
        title: title,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            hide();
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Convenience helper for error notifications.
  static void error(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(context, message: message, tone: AppTone.danger, title: title, duration: duration);
  }

  /// Convenience helper for success notifications.
  static void success(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message: message, tone: AppTone.success, title: title, duration: duration);
  }

  /// Convenience helper for warning notifications.
  static void warning(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message: message, tone: AppTone.warning, title: title, duration: duration);
  }

  /// Convenience helper for info notifications.
  static void info(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message: message, tone: AppTone.info, title: title, duration: duration);
  }

  /// Dismisses any active notification banner.
  static void hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null) {
      try {
        if (_currentEntry!.mounted) {
          _currentEntry?.remove();
        }
      } catch (_) {}
      _currentEntry = null;
    }
  }
}

class _AppNotificationBanner extends StatefulWidget {
  final String message;
  final AppTone tone;
  final String? title;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AppNotificationBanner({
    super.key,
    required this.message,
    required this.tone,
    this.title,
    this.duration = const Duration(seconds: 3),
    required this.onDismiss,
  });

  @override
  State<_AppNotificationBanner> createState() => _AppNotificationBannerState();
}

class _AppNotificationBannerState extends State<_AppNotificationBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    if (widget.duration > Duration.zero) {
      _autoDismissTimer = Timer(widget.duration, _handleDismiss);
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    if (!mounted || _isDismissing) return;
    _isDismissing = true;
    _autoDismissTimer?.cancel();
    try {
      await _controller.reverse();
    } catch (_) {}
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 10;
    final leftPadding = mediaQuery.padding.left + AppSpacing.md;
    final rightPadding = mediaQuery.padding.right + AppSpacing.md;

    final IconData iconData;
    final Color iconColor;
    final Color iconBgColor;
    final Color borderColor;

    switch (widget.tone) {
      case AppTone.danger:
        iconData = Icons.error_outline_rounded;
        iconColor = const Color(0xFFEF4444);
        iconBgColor = const Color(0x26EF4444);
        borderColor = const Color(0x59EF4444); // subtle red border
        break;
      case AppTone.success:
        iconData = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF10B981);
        iconBgColor = const Color(0x2610B981);
        borderColor = const Color(0x5910B981); // subtle green border
        break;
      case AppTone.warning:
        iconData = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFF59E0B);
        iconBgColor = const Color(0x26F59E0B);
        borderColor = const Color(0x59F59E0B); // subtle amber border
        break;
      case AppTone.verify:
        iconData = Icons.verified_outlined;
        iconColor = const Color(0xFF3B82F6);
        iconBgColor = const Color(0x263B82F6);
        borderColor = const Color(0xFF374151);
        break;
      case AppTone.brand:
        iconData = Icons.info_outline_rounded;
        iconColor = const Color(0xFF3B82F6);
        iconBgColor = const Color(0x263B82F6);
        borderColor = const Color(0xFF374151);
        break;
      case AppTone.info:
      case AppTone.neutral:
      default:
        iconData = Icons.info_outline_rounded;
        iconColor = const Color(0xFF3B82F6);
        iconBgColor = const Color(0x263B82F6);
        borderColor = const Color(0xFF374151); // subtle dark grey border
        break;
    }

    return Positioned(
      top: topPadding,
      left: leftPadding,
      right: rightPadding,
      child: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SlideTransition(
              position: _offsetAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Dismissible(
                  key: const ValueKey('app_notification_banner_dismissible'),
                  direction: DismissDirection.up,
                  onDismissed: (_) {
                    _autoDismissTimer?.cancel();
                    widget.onDismiss();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor,
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 18,
                          spreadRadius: 0,
                          offset: Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            iconData,
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.title != null && widget.title!.trim().isNotEmpty) ...[
                                Text(
                                  widget.title!.trim(),
                                  style: const TextStyle(
                                    color: Color(0xFFF9FAFB),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.1,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                widget.message,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF9FAFB),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _handleDismiss,
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a non-overlapping themed notification banner at the top of the screen.
/// Never covers bottom buttons or navigation bars.
void showAppSnackBar(
  BuildContext context,
  String message, {
  AppTone tone = AppTone.neutral,
  String? title,
  Duration duration = const Duration(seconds: 3),
}) {
  AppNotification.show(context, message: message, tone: tone, title: title, duration: duration);
}

// ─────────────────────────────────────────────────────────────────────────────
// Data display
// ─────────────────────────────────────────────────────────────────────────────

/// "Label   Value" row. Stacks label above value when space is tight
/// (narrow screens or large system font scale) so nothing overflows.
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final Color? valueColor;
  final double labelWidth;

  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.valueColor,
    this.labelWidth = 128,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final labelStyle = context.text.bodyMedium?.copyWith(color: p.textTertiary, fontSize: 13.5, height: 1.4);
    final valueStyle = context.text.bodyMedium?.copyWith(
      color: valueColor ?? p.textPrimary,
      fontWeight: FontWeight.w600,
      fontSize: 13.5,
      height: 1.4,
    );
    final valueColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: valueStyle),
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(detail!, style: context.text.bodySmall),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final stacked = constraints.maxWidth < 280 || scale > 1.3;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 2),
                valueColumn,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(label, style: labelStyle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: valueColumn),
            ],
          );
        },
      ),
    );
  }
}
