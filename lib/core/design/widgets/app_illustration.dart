import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:claimsupport/core/design/design.dart';

enum AppIllustrationKind {
  /// Warm paper slip + red capsule (Figma `Illustration/Prescription`, 51:282).
  prescription('assets/illustrations/illustration_prescription.svg', Size(129, 155)),

  /// Cool blue sheet with a second sheet behind + blue shield (`Illustration/Policy`, 51:304).
  policy('assets/illustrations/illustration_policy.svg', Size(136, 162));

  const AppIllustrationKind(this.asset, this.size);
  final String asset;

  /// Natural size (the SVG viewBox). Extra space is where the shadow was.
  final Size size;
}

/// A decorative illustration themed at runtime from the `Illustration` tokens.
/// Never tappable (design log D20).
class AppIllustration extends StatelessWidget {
  const AppIllustration(this.kind, {super.key});

  final AppIllustrationKind kind;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.asset(
        kind.asset,
        width: kind.size.width,
        height: kind.size.height,
        colorMapper: IllustrationColorMapper(context.illustration),
      ),
    );
  }
}
