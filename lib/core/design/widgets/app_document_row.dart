import 'package:flutter/material.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';
import 'package:claimsupport/core/design/widgets/app_pressable.dart';
import 'package:claimsupport/core/design/widgets/app_selection_checkbox.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';

enum AppDocumentState {
  ready(null),
  expired('Expired'),
  reading('Reading…'),
  failed('Couldn’t read'),
  unknown('Status unavailable');

  const AppDocumentState(this.label);
  final String? label;
}

class AppDocumentRow extends StatelessWidget {
  const AppDocumentRow({
    super.key,
    required this.type,
    required this.title,
    this.meta = '',
    this.timestamp,
    this.state = AppDocumentState.ready,
    this.selected,
    this.addAction = false,
    this.checkbox = false,
    this.grouped = false,
    this.category,
    this.leadingIcon,
    this.onLongPress,
    required this.onTap,
  });

  final DocumentCardType type;
  final String title;
  final String meta;
  final String? timestamp;
  final AppDocumentState state;

  /// Pass a value when this row represents a selection rather than navigation.
  final bool? selected;
  final bool addAction;
  final bool checkbox;
  final bool grouped;
  final String? category;
  final IconData? leadingIcon;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final warm = type == DocumentCardType.prescription;
    final title = this.title.trim().isEmpty ? (warm ? 'Prescription' : 'Policy') : this.title;
    final issue = state == AppDocumentState.expired || state == AppDocumentState.failed;
    final label = state.label;
    final description = [
      ?category,
      title,
      meta,
      ?timestamp,
      ?label,
    ].where((part) => part.isNotEmpty).join(', ');
    final metaStyle = AppTextStyles.captionRegular.copyWith(color: colors.textSecondary);
    final isSelected = selected == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badge = label == null
        ? null
        : DecoratedBox(
            decoration: ShapeDecoration(
              color: issue ? colors.statusNotCoveredBackground : colors.surfaceSelected,
              shape: DsShape.shape(DsShape.radiusFull),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s2),
              child: Text(
                label,
                style: AppTextStyles.chip.copyWith(color: issue ? colors.statusNotCovered : colors.textLink),
              ),
            ),
          );
    final inlineBadge = state == AppDocumentState.expired || state == AppDocumentState.reading;
    return Semantics(
      selected: checkbox ? null : selected,
      checked: checkbox ? selected : null,
      enabled: onTap != null,
      label: onTap == null ? description : null,
      child: AppPressableSurface(
        color: grouped ? (isSelected ? colors.surfaceSelected : Colors.transparent) : colors.surfaceCard,
        border: grouped
            ? BorderSide.none
            : BorderSide(
                color: isSelected ? colors.buttonPrimary : colors.borderSubtle,
                width: isSelected ? 2 : DsShape.strokeDefault,
              ),
        radius: grouped ? 0 : DsShape.radiusLg,
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: description,
        child: ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: leadingIcon != null ? 0 : DsSpace.s16,
              vertical: grouped ? DsSpace.s12 : DsSpace.s8,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: leadingIcon != null ? 42 : 48,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      // Phase F §0.4: mini illustration tile — #F4F6FA light / transparent dark.
                      color: addAction
                          ? colors.buttonPrimary
                          : isDark
                          ? Colors.transparent
                          : colors.surfaceCardSubtle,
                      shape: DsShape.shape(
                        14,
                        side: leadingIcon != null && !addAction
                            ? BorderSide(color: colors.borderSubtle)
                            : BorderSide.none,
                      ),
                    ),
                    child: addAction || leadingIcon != null
                        ? Icon(
                            leadingIcon ?? AppIcons.plus,
                            color: addAction ? colors.textOnButton : colors.iconDefault,
                          )
                        : Padding(
                            padding: const EdgeInsets.all(DsSpace.s4),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: AppIllustration(
                                warm ? AppIllustrationKind.prescription : AppIllustrationKind.policy,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: DsSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category case final name?)
                        Text(name, style: AppTextStyles.captionRegular.copyWith(color: colors.textSecondary)),
                      Text(
                        title,
                        maxLines: grouped && selected != null ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.rowTitle.copyWith(color: colors.textPrimary),
                      ),
                      if (timestamp case final time?)
                        Wrap(
                          spacing: DsSpace.s8,
                          children: [
                            if (meta.isNotEmpty)
                              Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: metaStyle),
                            Text(time, style: metaStyle),
                          ],
                        )
                      else if (meta.isNotEmpty)
                        Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: metaStyle),
                      if (!inlineBadge && badge != null) badge,
                    ],
                  ),
                ),
                if (inlineBadge && badge != null) ...[const SizedBox(width: DsSpace.s8), badge],
                const SizedBox(width: DsSpace.s8),
                if (selected == null && (onTap != null || leadingIcon != null))
                  Icon(AppIcons.caretRight, size: DsSize.iconSm, color: colors.iconDefault)
                else if (selected != null && checkbox)
                  AppSelectionCheckbox(checked: isSelected)
                else if (selected != null)
                  SizedBox.square(
                    dimension: DsSize.iconXl,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: isSelected ? colors.buttonPrimary : null,
                        shape: DsShape.shape(
                          DsShape.radiusFull,
                          side: BorderSide(color: isSelected ? colors.buttonPrimary : colors.borderStrong),
                        ),
                      ),
                      child: isSelected
                          ? Center(child: Icon(Icons.circle, size: 8, color: colors.surfaceCard))
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
