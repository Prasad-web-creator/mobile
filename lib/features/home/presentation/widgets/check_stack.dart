import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_pressable.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_card.dart';
import 'package:claimsupport/features/home/presentation/widgets/home_entrance.dart';

class AppCheckStack extends StatefulWidget {
  const AppCheckStack({
    super.key,
    required this.checks,
    required this.onOpen,
    this.onAction,
    this.onSeeAll,
    this.cardHeight,
    this.glass = false,
  });

  final List<CheckSummary> checks;
  final ValueChanged<CheckSummary> onOpen;
  final ValueChanged<CheckSummary>? onAction;
  final VoidCallback? onSeeAll;
  final double? cardHeight;
  final bool glass;

  @override
  State<AppCheckStack> createState() => _AppCheckStackState();
}

enum _StackMotion { idle, out, tuck, cancel, fade, insert }

class _AppCheckStackState extends State<AppCheckStack> with SingleTickerProviderStateMixin {
  static const _next = CustomSemanticsAction(label: 'Next check');
  static const _previous = CustomSemanticsAction(label: 'Previous check');
  static const _spring = HomeEntrance.spring;
  static const _commitDistance = 0.35;
  static const _commitVelocity = 700.0;
  static const _exitDistance = 0.7;
  static const _maxRotation = 8 * math.pi / 180;
  static const _peek = 12.0;
  static const _bottomInset = 4.0;
  static const _scaleStep = 0.06;

  late final _animation = AnimationController(vsync: this, animationBehavior: AnimationBehavior.preserve);
  final _drag = ValueNotifier(0.0);
  late final _frames = Listenable.merge([_animation, _drag]);
  _StackMotion _motion = _StackMotion.idle;
  late List<String> _order = widget.checks.take(5).map((check) => check.id).toList();
  CheckSummary? _outgoing;
  double _exit = 0;
  double _start = 0;
  Offset _pointerTravel = Offset.zero;
  bool _cyclingPrevious = false;
  bool _blockTap = false;

  @override
  void didUpdateWidget(AppCheckStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.checks.take(5).map((check) => check.id);
    final after = widget.checks.take(5).map((check) => check.id).toList();
    if (before.length != after.length || !before.indexed.every((entry) => entry.$2 == after[entry.$1])) {
      _animation.stop();
      _motion = _StackMotion.idle;
      _order = after;
      _outgoing = null;
      _drag.value = 0;
      if (widget.cardHeight != null &&
          before.isNotEmpty &&
          after.isNotEmpty &&
          !before.contains(after.first)) {
        _motion = _StackMotion.insert;
        _playInsert();
      }
    }
  }

  Future<void> _playInsert() async {
    try {
      if (DsMotion.reduced(context)) {
        _animation.value = 0;
        await _animation.animateTo(1, duration: DsMotion.base).orCancel;
      } else {
        await _animateSpring();
      }
      _reset();
    } on TickerCanceled {
      // The stack changed again before the new card settled.
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _advance({required bool previous}) {
    if (previous) {
      _order.insert(0, _order.removeLast());
    } else {
      _order.add(_order.removeAt(0));
    }
  }

  Future<void> _cycle(double width, double direction, {bool previous = false}) async {
    if (_order.length < 2 || _motion != _StackMotion.idle) return;
    final reduced = DsMotion.reduced(context);
    HapticFeedback.selectionClick();
    setState(() {
      _outgoing = widget.checks.firstWhere((check) => check.id == _order.first);
      _start = _drag.value;
      _cyclingPrevious = previous;
      _exit = direction * width * _exitDistance;
      _motion = reduced ? _StackMotion.fade : _StackMotion.out;
      if (reduced) _advance(previous: previous);
    });
    try {
      await _animation
          .animateTo(
            1,
            duration: Duration(milliseconds: reduced ? 150 : 140),
            curve: Curves.easeOut,
          )
          .orCancel;
      if (!reduced) {
        setState(() {
          _advance(previous: previous);
          _motion = _StackMotion.tuck;
        });
        await _animateSpring();
      }
      _reset();
    } on TickerCanceled {
      // A refreshed list or disposal interrupted the gesture.
    }
  }

  Future<void> _animateSpring({double velocity = 0}) {
    _animation.value = 0;
    return _animation.animateWith(SpringSimulation(_spring, 0, 1, velocity)).orCancel;
  }

  Future<void> _settleDrag([double velocity = 0]) async {
    if (_motion != _StackMotion.idle || _drag.value == 0) return;
    if (DsMotion.reduced(context)) {
      _drag.value = 0;
      return;
    }
    setState(() {
      _start = _drag.value;
      _motion = _StackMotion.cancel;
    });
    try {
      await _animateSpring(velocity: -velocity / _start);
      _reset();
    } on TickerCanceled {
      // A refreshed list or disposal interrupted the gesture.
    }
  }

  void _reset() {
    setState(() {
      _drag.value = 0;
      _animation.value = 0;
      _outgoing = null;
      _motion = _StackMotion.idle;
    });
  }

  void _endDrag(DragEndDetails details, double width) {
    final dx = _drag.value;
    final velocity = details.primaryVelocity ?? 0;
    if (dx.abs() > _commitDistance * width || velocity.abs() > _commitVelocity) {
      _cycle(width, (dx == 0 ? velocity : dx).sign);
    } else {
      _settleDrag(velocity);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_order.isEmpty) return const SizedBox.shrink();
    final checks = {for (final check in widget.checks.take(5)) check.id: check};
    final ids = _cyclingPrevious && _motion == _StackMotion.out
        ? [_order.first, _order.last, ..._order.skip(1).take(_order.length - 2)]
        : _order;
    final visible = [for (final id in ids.take(3)) checks[id]!];
    final fixedHeight = widget.cardHeight;
    final depth = fixedHeight == null ? (visible.length - 1) * _peek : 2 * _peek;
    final entrance = HomeEntrance.maybeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Listener(
                onPointerDown: (_) {
                  _pointerTravel = Offset.zero;
                  _blockTap = _motion != _StackMotion.idle;
                },
                onPointerMove: (event) {
                  _pointerTravel += event.delta;
                  if (_pointerTravel.distanceSquared > 64) _blockTap = true;
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  excludeFromSemantics: true,
                  dragStartBehavior: DragStartBehavior.down,
                  onHorizontalDragUpdate: visible.length < 2
                      ? null
                      : (details) {
                          if (_motion == _StackMotion.idle) {
                            _drag.value += details.delta.dx;
                          }
                        },
                  onHorizontalDragEnd: visible.length < 2 ? null : (details) => _endDrag(details, width),
                  onHorizontalDragCancel: visible.length < 2 ? null : _settleDrag,
                  child: AnimatedBuilder(
                    animation: entrance == null ? _frames : Listenable.merge([_frames, entrance.progress]),
                    child: fixedHeight != null
                        ? SizedBox(height: fixedHeight + depth + _bottomInset)
                        : Padding(
                            padding: EdgeInsets.only(bottom: depth),
                            child: IndexedStack(
                              index: null,
                              sizing: StackFit.passthrough,
                              children: [
                                for (final check in checks.values)
                                  AppCheckCard(
                                    check: check,
                                    onAction: widget.onAction == null || check.actionRoute == null
                                        ? null
                                        : () {},
                                  ),
                              ],
                            ),
                          ),
                    builder: (context, measuringCards) => Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.passthrough,
                      children: [
                        measuringCards!,
                        ..._layers(
                          context,
                          visible,
                          depth,
                          width,
                          entrance?.spreadAt(entrance.progress.value) ?? 1,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.onSeeAll case final onSeeAll?) ...[
          const SizedBox(height: DsSpace.s8),
          CheckStackViewAll(onTap: onSeeAll),
        ],
      ],
    );
  }

  List<Widget> _layers(
    BuildContext context,
    List<CheckSummary> visible,
    double depth,
    double width,
    double spread,
  ) {
    final reduced = DsMotion.reduced(context);
    final t = _animation.value;
    final x = switch (_motion) {
      _StackMotion.out => lerpDouble(_start, _exit, t)!,
      _StackMotion.cancel => _start * (1 - t),
      _StackMotion.idle when !reduced => _drag.value,
      _ => 0.0,
    };
    final advance =
        _motion == _StackMotion.out || _motion == _StackMotion.cancel || _motion == _StackMotion.idle
        ? (x.abs() / (_commitDistance * width)).clamp(0.0, 1.0)
        : 0.0;
    final front = visible.first;
    final canTap = _motion == _StackMotion.idle && _drag.value == 0;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget layer(
      CheckSummary check, {
      required double position,
      double dx = 0,
      double angle = 0,
      double content = 1,
      double opacity = 1,
      bool interactive = false,
      bool shadow = false,
      bool backLayer = true,
      bool blurGlass = true,
      double lift = 0,
    }) {
      final scale = 1 - position * _scaleStep;
      final colors = context.colors;
      final fill = position > 1
          ? Color.lerp(colors.surfaceStack1, colors.surfaceStack2, (position - 1).clamp(0, 1))
          : Color.lerp(colors.surfaceCard, colors.surfaceStack1, position.clamp(0, 1));
      Widget card = AppCheckCard(
        surfaceColor: widget.glass ? null : fill,
        glass: widget.glass,
        backLayer: backLayer,
        blurGlass: blurGlass,
        key: ValueKey(check.id),
        check: check,
        contentOpacity: content,
        fitContent: widget.cardHeight != null,
        onTap: interactive
            ? () {
                if (!_blockTap) widget.onOpen(check);
              }
            : null,
        onAction: widget.onAction == null || check.actionRoute == null
            ? null
            : () {
                if (interactive && !_blockTap) widget.onAction!(check);
              },
        customActions: !interactive || visible.length < 2
            ? null
            : {_next: () => _cycle(width, 1), _previous: () => _cycle(width, -1, previous: true)},
      );
      if (shadow && !dark) {
        card = DecoratedBox(
          decoration: widget.glass
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(DsShape.radiusXl),
                  boxShadow: [DsEffect.checkStackShadow(lift: advance, blurStyle: BlurStyle.outer)],
                )
              : ShapeDecoration(
                  shape: DsShape.shape(DsShape.radiusXl),
                  shadows: [DsEffect.checkStackShadow(lift: advance)],
                ),
          child: card,
        );
      }
      final height = widget.cardHeight;
      return Positioned(
        key: ValueKey(check.id),
        left: 0,
        right: 0,
        top: 0,
        // Scale the width and keep the card's full-height silhouette visible
        // from its top-aligned slot, so successive layers peek out by 12pt.
        height: height == null ? null : height / scale,
        bottom: height == null ? depth : null,
        child: IgnorePointer(
          ignoring: !interactive,
          child: ExcludeSemantics(
            excluding: !interactive,
            child: Transform.translate(
              offset: Offset(dx, position * _peek + lift),
              child: Transform.rotate(
                angle: angle,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: Opacity(opacity: opacity, child: card),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final tuck = _motion == _StackMotion.tuck;
    final fade = _motion == _StackMotion.fade;
    final tuckIndex = _cyclingPrevious ? 1 : visible.length - 1;
    final inserting = _motion == _StackMotion.insert;
    final insertOffset = inserting && !reduced ? 1 - t : 0.0;
    double rotation(double dx) => (dx / width).clamp(-1.0, 1.0) * _maxRotation;
    return [
      if (tuck)
        layer(
          _outgoing!,
          position: tuckIndex * t,
          dx: _exit * (1 - t),
          angle: _exit.sign * _maxRotation * (1 - t),
          content: 1 - t,
        ),
      for (var i = visible.length - 1; i > 0; i--)
        if ((!tuck || i != tuckIndex) && (!fade || visible[i].id != _outgoing!.id))
          layer(
            visible[i],
            position: (i - advance - insertOffset) * spread,
            content: i == 1 ? math.max(advance, insertOffset) : 0,
          ),
      layer(
        front,
        position: 0,
        dx: x,
        angle: _motion == _StackMotion.out
            ? lerpDouble(rotation(_start), _exit.sign * _maxRotation, t)!
            : rotation(x),
        opacity: fade || inserting ? t : 1,
        lift: -12 * insertOffset,
        interactive: canTap,
        shadow: true,
        backLayer: false,
      ),
      if (fade) layer(_outgoing!, position: 0, opacity: 1 - t, backLayer: false, blurGlass: false),
    ];
  }
}

class CheckStackViewAll extends StatelessWidget {
  const CheckStackViewAll({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          Expanded(child: Divider(color: c.borderSubtle, thickness: 1)),
          AppPressableSurface(
            color: c.surfaceCard,
            border: BorderSide(color: c.borderSubtle),
            radius: DsShape.radiusFull,
            onTap: onTap,
            semanticLabel: 'View all',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: SizedBox(
                  height: 34,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s6,
                    children: [
                      Text('View all', style: AppTextStyles.label.copyWith(color: c.textPrimary)),
                      Icon(AppIcons.caretRight, size: DsSize.iconXs, color: c.iconDefault),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: c.borderSubtle, thickness: 1)),
        ],
      ),
    );
  }
}
