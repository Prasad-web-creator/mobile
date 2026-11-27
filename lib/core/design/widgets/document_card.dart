import 'package:flutter/material.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';
import 'package:claimsupport/core/design/widgets/app_pressable.dart';
import 'package:claimsupport/core/design/widgets/app_placeholder_pulse.dart';

enum DocumentCardType { prescription, policy }

class AppDocumentCard extends StatelessWidget {
  const AppDocumentCard({super.key, required this.type, required this.count, required this.onTap});

  final DocumentCardType type;
  final int? count;
  final VoidCallback onTap;

  static String countLabel(int count) => count > 99 ? '99+' : '${count.clamp(0, 99)}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final prescription = type == DocumentCardType.prescription;
    final title = prescription ? 'Prescriptions' : 'Policies';
    final count = this.count;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = DsSpace.s4;
        const ring = DsShape.strokeDefault;
        const caretInset = DsSpace.s12;
        const caretClearance = caretInset + DsSize.controlSm + gap;
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        );
        double widestTitle(TextStyle style) {
          painter.text = TextSpan(text: 'Prescriptions', style: style);
          painter.layout();
          return painter.width;
        }

        final availableWidth = constraints.maxWidth - 2 * ring - DsSpace.s16 - caretClearance;
        final labelStyle = widestTitle(AppTextStyles.subheadStrong) <= availableWidth
            ? AppTextStyles.subheadStrong
            : AppTextStyles.captionStrong;
        final fitsBesideCaret = widestTitle(labelStyle) <= availableWidth;
        final titleStyle = labelStyle.copyWith(color: c.textPrimary);
        final inset = widestTitle(titleStyle) <= constraints.maxWidth - DsSpace.cardPadding * 2
            ? DsSpace.s16
            : DsSpace.s8;
        painter.dispose();

        return AppPressableSurface(
          color: c.surfaceCardSubtle,
          border: BorderSide(color: c.borderSubtle),
          radius: 22,
          onTap: onTap,
          semanticLabel: count == null ? title : '$title, ${countLabel(count)}',
          child: ExcludeSemantics(
            child: Stack(
              children: [
                PositionedDirectional(
                  end: prescription ? DsSize.prescriptionArtRight : DsSize.policyArtRight,
                  bottom: DsSize.documentArtBottom,
                  child: AppIllustration(
                    prescription ? AppIllustrationKind.prescription : AppIllustrationKind.policy,
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxWidth / (173 / 164) - 2 * ring),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      inset,
                      fitsBesideCaret ? DsSpace.s16 : caretClearance,
                      fitsBesideCaret ? caretClearance : inset,
                      DsSpace.cardPadding,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: titleStyle),
                        const SizedBox(height: DsSpace.s2),
                        SizedBox(
                          height: MediaQuery.textScalerOf(context).scale(36),
                          child: AnimatedSwitcher(
                            duration: DsMotion.reduced(context) ? Duration.zero : DsMotion.base,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: AlignmentDirectional.centerStart,
                              children: [
                                ...previous.map((child) => ExcludeSemantics(child: child)),
                                ?current,
                              ],
                            ),
                            child: count == null
                                ? AppPlaceholderPulse(
                                    child: SizedBox(
                                      width: 24,
                                      height: 28,
                                      child: DecoratedBox(
                                        decoration: ShapeDecoration(
                                          color: c.surfacePressed,
                                          shape: DsShape.shape(DsShape.radiusXs),
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    countLabel(count),
                                    key: ValueKey(countLabel(count)),
                                    style: AppTextStyles.numberCount.copyWith(
                                      color: count <= 0 ? c.textTertiary : c.textPrimary,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: caretInset,
                  end: caretInset,
                  child: SizedBox.square(
                    dimension: DsSize.controlSm,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: c.surfaceCard,
                        shape: DsShape.shape(DsShape.radiusFull, side: BorderSide(color: c.borderSubtle)),
                      ),
                      child: Icon(AppIcons.caretRight, size: DsSize.iconSm, color: c.iconDefault),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
