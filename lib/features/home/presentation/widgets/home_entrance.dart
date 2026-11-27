import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class HomeEntrance extends InheritedWidget {
  const HomeEntrance({super.key, required this.progress, required this.reduced, required super.child});

  static const duration = Duration(milliseconds: 650);
  static const reducedDuration = Duration(milliseconds: 150);
  static const spring = SpringDescription(mass: 1, stiffness: 320, damping: 28);
  static final _spread = SpringSimulation(spring, 0, 1, 0);

  final Animation<double> progress;
  final bool reduced;

  static HomeEntrance? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeEntrance>();

  double spreadAt(double value) {
    if (reduced || value >= 1) return 1;
    final seconds = (value * duration.inMilliseconds - 220).clamp(0.0, double.infinity) / 1000;
    return _spread.x(seconds).clamp(0.0, 1);
  }

  @override
  bool updateShouldNotify(HomeEntrance oldWidget) =>
      progress != oldWidget.progress || reduced != oldWidget.reduced;
}

class HomeReveal extends StatelessWidget {
  const HomeReveal({
    super.key,
    required this.delay,
    required this.duration,
    this.rise = 0,
    required this.child,
  });

  final int delay;
  final int duration;
  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final entrance = HomeEntrance.maybeOf(context);
    if (entrance == null) return child;
    final total = HomeEntrance.duration.inMilliseconds;
    return AnimatedBuilder(
      animation: entrance.progress,
      child: child,
      builder: (context, child) {
        final progress = entrance.progress.value;
        final value = entrance.reduced
            ? progress
            : Interval(
                delay / total,
                (delay + duration) / total,
                curve: Curves.easeOutCubic,
              ).transform(progress);
        return IgnorePointer(
          ignoring: value == 0,
          child: Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, entrance.reduced ? 0 : rise * (1 - value)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
