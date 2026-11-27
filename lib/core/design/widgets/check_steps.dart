import 'package:claimsupport/core/localization/localization.dart';
import 'package:flutter/material.dart';
import 'package:claimsupport/core/design/app_icons.dart';

import 'package:claimsupport/core/design/design.dart';

/// The three hero steps on the empty Home (handoff §5.2.4): a 32pt tile + label
/// each, joined by a dotted vertical connector in `border/strong`.
class CheckSteps extends StatelessWidget {
  const CheckSteps({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final i = context.illustration;
    final steps = [
      (AppIcons.pillFill, i.paperWarmTop, i.paperWarmEdge, i.accentRedTop, context.l10n.sharedSelectPrescription),
      (AppIcons.shieldCheckFill, i.paperCoolTop, i.paperCoolEdge, i.accentBlueTop, context.l10n.sharedSelectPolicy),
      (AppIcons.listChecks, c.surfaceCard, c.borderSubtle, c.textPrimary, context.l10n.sharedViewClaimCoverage),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var k = 0; k < steps.length; k++) ...[
          if (k > 0) _DottedConnector(color: c.borderStrong),
          Row(
            children: [
              Container(
                width: DsSize.controlSm,
                height: DsSize.controlSm,
                decoration: ShapeDecoration(
                  color: steps[k].$2,
                  shape: DsShape.shape(
                    DsShape.radiusSm,
                    side: BorderSide(color: steps[k].$3, width: DsShape.strokeDefault),
                  ),
                ),
                child: Icon(steps[k].$1, size: DsSize.iconMd, color: steps[k].$4),
              ),
              const SizedBox(width: DsSpace.s12),
              Expanded(
                child: Text(steps[k].$5, style: AppTextStyles.bodyStrong.copyWith(color: c.textOnGradient)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DottedConnector extends StatelessWidget {
  const _DottedConnector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: DsSize.controlSm,
      height: DsSpace.s16,
      child: CustomPaint(painter: _DotsPainter(color)),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const r = 1.0;
    const gap = 4.0;
    for (double y = gap / 2; y <= size.height - r; y += gap) {
      canvas.drawCircle(Offset(size.width / 2, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}
