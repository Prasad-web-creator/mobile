import 'package:claimsupport/core/design/design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paints the inset Android leaves transparent in edge-to-edge mode.
class AndroidNavigationBackground extends StatelessWidget {
  const AndroidNavigationBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return child;
    final showBackground = bottom > 0 && MediaQuery.viewInsetsOf(context).bottom == 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showBackground)
          PositionedDirectional(
            bottom: 0,
            start: 0,
            end: 0,
            height: bottom,
            child: IgnorePointer(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarContrastEnforced: false,
                  systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
                ),
                child: ColoredBox(color: context.colors.backgroundPage),
              ),
            ),
          ),
      ],
    );
  }
}
