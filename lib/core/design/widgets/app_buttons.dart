import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_pressable.dart';

enum AppButtonStyle { primary, secondary, danger }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.busy = false,
    this.haptic = false,
    this.showPressed = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool busy;
  final bool haptic;

  /// Shows the interaction state in the component gallery.
  final bool showPressed;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onPressed != null && !widget.busy;
    final primary = widget.style == AppButtonStyle.primary;
    final danger = widget.style == AppButtonStyle.danger;
    final pressed = enabled && (_pressed || widget.showPressed);
    final foreground = enabled || widget.busy
        ? primary || danger
              ? c.textOnButton
              : pressed
              ? c.textPrimary
              : c.buttonOnSecondary
        : c.textTertiary;
    final fill = danger && (enabled || widget.busy)
        ? c.statusNotCovered
        : switch ((enabled || widget.busy, primary, pressed)) {
            (false, _, _) => c.buttonDisabled,
            (true, true, true) => c.buttonPrimaryPressed,
            (true, true, false) => c.buttonPrimary,
            (true, false, true) => c.surfacePressed,
            (true, false, false) => c.buttonSecondary,
          };
    return AppPressable(
      onTap: enabled ? widget.onPressed : null,
      onPressedChanged: (pressed) => setState(() => _pressed = pressed),
      semanticLabel: widget.label,
      haptic: widget.haptic,
      showPressed: widget.showPressed,
      child: AnimatedContainer(
        duration: DsMotion.fast,
        curve: DsMotion.fastCurve,
        constraints: const BoxConstraints(minHeight: DsSize.controlXl),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s8),
        decoration: ShapeDecoration(color: fill, shape: DsShape.shape(DsShape.radiusFull)),
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.busy) ...[
                SizedBox.square(
                  dimension: DsSize.iconLg,
                  child: CircularProgressIndicator(strokeWidth: DsShape.strokeDefault, color: foreground),
                ),
                const SizedBox(width: DsSpace.s8),
              ],
              if (!widget.busy && widget.icon != null) ...[
                Icon(widget.icon, size: DsSize.iconMd, color: foreground),
                const SizedBox(width: DsSpace.s8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.showPressed = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool showPressed;

  @override
  Widget build(BuildContext context) => _GlassButton(
    label: label,
    size: 40,
    usePageSurface: true,
    blur: DsEffect.glassBlur,
    onPressed: onPressed,
    showPressed: showPressed,
    child: Icon(
      icon,
      size: DsSize.iconLg,
      color: onPressed == null ? context.colors.textTertiary : context.colors.iconDefault,
    ),
  );
}

class AppGlassAvatar extends StatelessWidget {
  const AppGlassAvatar({super.key, required this.initials, required this.onPressed});

  final String initials;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = context.colors.textOnGradient;
    return _GlassButton(
      label: 'Profile',
      size: DsSize.avatarMd,
      blur: DsEffect.avatarBlur,
      onPressed: onPressed,
      child: initials.isEmpty
          ? Icon(AppIcons.user, size: DsSize.iconLg, color: foreground)
          : Text(initials, style: AppTextStyles.captionStrong.copyWith(color: foreground)),
    );
  }
}

class _GlassButton extends StatefulWidget {
  const _GlassButton({
    required this.label,
    required this.size,
    required this.blur,
    required this.onPressed,
    required this.child,
    this.usePageSurface = false,
    this.showPressed = false,
  });

  final String label;
  final double size;
  final double blur;
  final bool usePageSurface;
  final VoidCallback? onPressed;
  final Widget child;
  final bool showPressed;

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPressable(
      onTap: widget.onPressed,
      onPressedChanged: (pressed) => setState(() => _pressed = pressed),
      semanticLabel: widget.label,
      showPressed: widget.showPressed,
      child: SizedBox.square(
        dimension: DsSize.controlLg,
        child: Center(
          child: SizedBox.square(
            dimension: widget.size,
            child: ClipRSuperellipse(
              borderRadius: const BorderRadius.all(Radius.circular(DsShape.radiusFull)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
                child: AnimatedContainer(
                  duration: DsMotion.fast,
                  curve: DsMotion.fastCurve,
                  decoration: ShapeDecoration(
                    color: _pressed || widget.showPressed || widget.usePageSurface ? c.surfacePressed : c.surfaceGlass,
                    shape: DsShape.shape(
                      DsShape.radiusFull,
                      side: BorderSide(
                        color: widget.usePageSurface ? c.borderSubtle : c.borderGlass,
                        width: DsShape.strokeHairline,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: ExcludeSemantics(child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppLink extends StatelessWidget {
  const AppLink({super.key, required this.label, required this.onPressed, this.trailing, this.showPressed = false});

  final String label;
  final VoidCallback onPressed;
  final IconData? trailing;
  final bool showPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPressableSurface(
      color: Colors.transparent,
      showPressed: showPressed,
      onTap: onPressed,
      semanticLabel: label,
      radius: DsShape.radiusFull,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: DsSize.controlLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(label, style: AppTextStyles.label.copyWith(color: c.textLink)),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: DsSpace.s4),
                  Icon(trailing, size: DsSize.iconXs, color: c.textLink),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
