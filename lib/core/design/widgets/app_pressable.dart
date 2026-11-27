import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

import 'package:claimsupport/core/design/design.dart';

/// Press feedback for every tappable card, chip and button (handoff §5.7):
/// scales to 0.97 over motion/fast and springs back on release. No Material
/// ripple. With Reduce Motion on, only the optional pressed fill changes.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.haptic = false,
    this.semanticLabel,
    this.button = true,
    this.onPressedChanged,
    this.customActions,
    this.showPressed = false,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// `HapticFeedback.lightImpact()` on tap (New check, Start your first check, +).
  final bool haptic;
  final String? semanticLabel;
  final bool button;
  final ValueChanged<bool>? onPressedChanged;
  final Map<CustomSemanticsAction, VoidCallback>? customActions;
  final bool showPressed;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 1);

  void _down() {
    widget.onPressedChanged?.call(true);
    if (DsMotion.reduced(context)) return;
    _c.animateTo(DsMotion.pressScale, duration: DsMotion.fast, curve: DsMotion.fastCurve);
  }

  void _up() {
    widget.onPressedChanged?.call(false);
    if (DsMotion.reduced(context)) {
      _c.value = 1;
      return;
    }
    _c.animateWith(SpringSimulation(DsMotion.spring, _c.value, 1, _c.velocity));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: widget.button,
      enabled: enabled,
      label: widget.semanticLabel,
      customSemanticsActions: widget.customActions,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _down() : null,
        onTapCancel: enabled ? _up : null,
        onLongPress: widget.onLongPress,
        onTapUp: enabled ? (_) => _up() : null,
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.scale(
            scale: widget.showPressed && !DsMotion.reduced(context) ? DsMotion.pressScale : _c.value,
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Card surface with continuous corners whose fill switches to
/// `surface/pressed` while pressed (cards only, handoff §5.7).
class AppPressableSurface extends StatefulWidget {
  const AppPressableSurface({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.radius = DsShape.radiusXl,
    this.border,
    this.semanticLabel,
    this.clip = Clip.antiAlias,
    this.showPressed = false,
    this.customActions,
    this.onLongPress,
    this.gradient,
    this.backdropFilter,
  });

  final Color color;
  final LinearGradient? gradient;
  final ImageFilter? backdropFilter;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final BorderSide? border;
  final String? semanticLabel;
  final Clip clip;
  final bool showPressed;
  final Map<CustomSemanticsAction, VoidCallback>? customActions;

  @override
  State<AppPressableSurface> createState() => _AppPressableSurfaceState();
}

class _AppPressableSurfaceState extends State<AppPressableSurface> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final shape = DsShape.shape(widget.radius, side: widget.border ?? BorderSide.none);
    final pressed = _pressed || widget.showPressed;
    final pressedColor = context.colors.surfacePressed;
    final gradient = widget.gradient;
    Widget surface = AnimatedContainer(
      duration: DsMotion.fast,
      curve: DsMotion.fastCurve,
      clipBehavior: widget.clip,
      decoration: ShapeDecoration(
        color: gradient == null ? (pressed ? pressedColor : widget.color) : null,
        gradient: gradient != null && pressed
            ? LinearGradient(begin: gradient.begin, end: gradient.end, colors: [pressedColor, pressedColor])
            : gradient,
        shape: shape,
      ),
      child: widget.child,
    );
    if (widget.backdropFilter case final filter?) {
      surface = ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        clipBehavior: widget.clip,
        child: BackdropFilter(filter: filter, child: surface),
      );
    }
    if (widget.onTap == null) return surface;
    return AppPressable(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onPressedChanged: _set,
      semanticLabel: widget.semanticLabel,
      customActions: widget.customActions,
      showPressed: widget.showPressed,
      child: surface,
    );
  }
}
