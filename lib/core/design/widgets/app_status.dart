import 'package:claimsupport/core/localization/localization.dart';
import 'package:flutter/material.dart';
import 'package:claimsupport/core/localization/translation_mapper.dart';

import 'package:claimsupport/core/design/app_check_status.dart';
import 'package:claimsupport/core/design/design.dart';

Color _dot(AppColors c, CheckStatusKind kind) => switch (kind) {
  CheckStatusKind.covered => c.statusCovered,
  CheckStatusKind.partial => c.statusPartialDot,
  CheckStatusKind.notCovered || CheckStatusKind.failed => c.statusNotCovered,
  CheckStatusKind.checking || CheckStatusKind.other || CheckStatusKind.verification => c.textTertiary,
};

class AppStatusDot extends StatelessWidget {
  const AppStatusDot({super.key, required this.kind, this.size = DsSize.indicatorDot, this.color});

  final CheckStatusKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color ?? _dot(context.colors, kind)),
      ),
    ),
  );
}

class AppStatusLabel extends StatelessWidget {
  const AppStatusLabel({super.key, required this.kind, required this.label, this.prominent = false});

  final CheckStatusKind kind;
  final String label;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = kind.coverageLabel == null ? c.textSecondary : c.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppStatusDot(kind: kind),
        const SizedBox(width: DsSpace.s8),
        Flexible(
          child: Text(
            localizedCheckStatus(context.l10n, kind.coverageLabel ?? label),
            style: (prominent ? AppTextStyles.headline : AppTextStyles.captionStrong).copyWith(
              color: foreground,
            ),
          ),
        ),
      ],
    );
  }
}

class AppStatusPill extends StatelessWidget {
  const AppStatusPill({super.key, required this.kind, required this.label});

  final CheckStatusKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = switch (kind) {
      CheckStatusKind.covered => c.statusCoveredBackground,
      CheckStatusKind.partial => c.statusPartialBackground,
      CheckStatusKind.notCovered || CheckStatusKind.failed => c.statusNotCoveredBackground,
      CheckStatusKind.other ||
      CheckStatusKind.checking ||
      CheckStatusKind.verification => c.surfaceCardSubtle,
    };
    return DecoratedBox(
      decoration: ShapeDecoration(color: fill, shape: DsShape.shape(DsShape.radiusFull)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s6),
        child: AppStatusLabel(kind: kind, label: label),
      ),
    );
  }
}
