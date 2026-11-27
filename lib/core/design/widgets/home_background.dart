import 'package:flutter/material.dart';

import 'package:claimsupport/core/design/design.dart';

/// Pre-blurred artwork. Flutter selects a resolution variant when available.
class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = Theme.of(context).brightness.name;
    return IgnorePointer(
      child: Image.asset(
        'assets/backgrounds/home_bg_$mode.png',
        height: DsSize.homeBackgroundHeight,
        width: double.infinity,
        fit: BoxFit.fill,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
