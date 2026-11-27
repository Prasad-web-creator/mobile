import 'package:flutter/material.dart';

import 'package:claimsupport/core/design/design.dart';

class AppPlaceholderPulse extends StatefulWidget {
  const AppPlaceholderPulse({super.key, required this.child});

  final Widget child;

  @override
  State<AppPlaceholderPulse> createState() => _AppPlaceholderPulseState();
}

class _AppPlaceholderPulseState extends State<AppPlaceholderPulse> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final _opacity = _pulse.drive(CurveTween(curve: Curves.easeInOut)).drive(Tween(begin: 0.6, end: 1.0));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DsMotion.reduced(context)) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _opacity, child: widget.child);
}
