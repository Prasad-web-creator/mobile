import 'package:claimsupport/core/localization/localization.dart';
import 'package:flutter/material.dart';
import 'package:claimsupport/core/localization/translation_mapper.dart';

import 'package:claimsupport/core/design/app_check_status.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_pressable.dart';
import 'package:claimsupport/core/design/widgets/app_status.dart';

enum AppCheckFilter {
  all('All'),
  covered('Fully covered'),
  partial('Partially covered'),
  notCovered('Not covered'),
  verification('Needs verification');

  const AppCheckFilter(this.label);
  final String label;
}

class AppFilterChips extends StatelessWidget {
  const AppFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  final AppCheckFilter selected;
  final ValueChanged<AppCheckFilter> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => AppFilterChipRow<AppCheckFilter>(
    padding: padding,
    key: const PageStorageKey('coverage-filter-offset'),
    options: {for (final filter in AppCheckFilter.values) filter: filter.label},
    selected: selected,
    onChanged: onChanged,
  );
}

class AppFilterChipRow<T> extends StatelessWidget {
  const AppFilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        spacing: DsSpace.s8,
        children: [
          for (final option in options.entries)
            _Choice(
              selected: selected == option.key,
              semanticLabel: option.value,
              onTap: onChanged == null ? null : () => onChanged!(option.key),
              inverse: true,
              child: Text(
                option.value,
                style: AppTextStyles.label.copyWith(
                  color: selected == option.key
                      ? context.colors.buttonOnSecondary
                      : context.colors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

@immutable
class AppPolicyOption {
  const AppPolicyOption({
    required this.label,
    required this.kind,
    required this.statusLabel,
    this.best = false,
  });

  final String label;
  final CheckStatusKind kind;
  final String statusLabel;
  final bool best;
}

class AppPolicySwitcher extends StatelessWidget {
  const AppPolicySwitcher({
    super.key,
    required this.policies,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<AppPolicyOption> policies;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: DsSpace.s8,
      runSpacing: DsSpace.s8,
      children: [
        for (final (i, policy) in policies.indexed)
          _Choice(
            selected: i == selectedIndex,
            semanticLabel: [
              policy.label,
              localizedCheckStatus(context.l10n, policy.kind.coverageLabel ?? policy.statusLabel),
              if (policy.best) context.l10n.sharedBest,
            ].join(', '),
            onTap: () => onChanged(i),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppStatusDot(kind: policy.kind),
                const SizedBox(width: DsSpace.s8),
                Flexible(
                  child: Text(
                    policy.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(color: c.textPrimary),
                  ),
                ),
                if (policy.best) ...[
                  const SizedBox(width: DsSpace.s6),
                  DecoratedBox(
                    decoration: ShapeDecoration(color: c.surfaceCard, shape: DsShape.shape(DsShape.radiusXs)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4, vertical: DsSpace.s2),
                      child: Text(context.l10n.sharedBest, style: AppTextStyles.captionStrong.copyWith(color: c.textPrimary)),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.inverse = false,
  });

  final bool selected;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      label: onTap == null ? semanticLabel : null,
      button: onTap == null ? true : null,
      enabled: onTap == null ? false : null,
      child: AppPressableSurface(
        color: selected ? (inverse ? c.buttonSecondary : c.surfaceSelected) : c.surfaceCard,
        border: BorderSide(color: c.borderSubtle, width: DsShape.strokeHairline),
        radius: DsShape.radiusFull,
        semanticLabel: semanticLabel,
        onTap: onTap,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: inverse ? DsSize.controlMd : DsSize.controlLg),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: DsSpace.s12,
                vertical: inverse ? DsSpace.s4 : DsSpace.s8,
              ),
              child: Align(alignment: Alignment.center, widthFactor: 1, heightFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
