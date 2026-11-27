import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';
import 'package:claimsupport/core/design/widgets/app_pressable.dart';
import 'package:claimsupport/core/design/widgets/app_selection_checkbox.dart';
import 'package:claimsupport/core/design/widgets/app_status.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';

class AppCheckCard extends StatelessWidget {
  const AppCheckCard({
    super.key,
    required this.check,
    this.onTap,
    this.onAction,
    this.customActions,
    this.contentOpacity = 1,
    this.fitContent = false,
    this.surfaceColor,
    this.glass = false,
    this.backLayer = false,
    this.blurGlass = true,
  });

  final CheckSummary check;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final Map<CustomSemanticsAction, VoidCallback>? customActions;
  final double contentOpacity;
  final bool fitContent;
  final Color? surfaceColor;
  final bool glass;
  final bool backLayer;
  final bool blurGlass;

  static double heightFor(BuildContext context) =>
      158 + ((MediaQuery.textScalerOf(context).scale(16) / 16 - 1) * 94).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) => AppCheckCardSurface(
    surfaceColor: surfaceColor,
    glass: glass,
    backLayer: backLayer,
    blurGlass: blurGlass,
    onTap: onTap,
    customActions: customActions,
    child: TickerMode(
      enabled: contentOpacity > 0,
      child: Opacity(
        opacity: contentOpacity,
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            // The surface's ring contributes 2pt to its total height.
            height: fitContent && constraints.hasBoundedHeight
                ? constraints.maxHeight
                : heightFor(context) - 2 + (_noteFor(check) == null ? 0 : 22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: _CheckContent(
                check: check,
                onAction: onAction,
                home: true,
                compact: fitContent,
                glass: glass,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AppCheckCardSurface extends StatelessWidget {
  const AppCheckCardSurface({
    super.key,
    required this.child,
    this.surfaceColor,
    this.glass = false,
    this.backLayer = false,
    this.blurGlass = true,
    this.onTap,
    this.customActions,
  });

  static final _frontBlur = ImageFilter.blur(sigmaX: DsEffect.checkCardBlur, sigmaY: DsEffect.checkCardBlur);

  final Widget child;
  final Color? surfaceColor;
  final bool glass;
  final bool backLayer;
  final bool blurGlass;
  final VoidCallback? onTap;
  final Map<CustomSemanticsAction, VoidCallback>? customActions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPressableSurface(
      color: glass && backLayer ? c.surfaceCard.withValues(alpha: 0.35) : surfaceColor ?? c.surfaceCard,
      border: BorderSide(color: glass ? c.borderCheckGlass : c.borderSubtle),
      gradient: glass && !backLayer
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.surfaceCheckGlassTop, c.surfaceCheckGlassTop, c.surfaceCard],
              stops: const [0, 0.18, 0.78],
            )
          : null,
      backdropFilter: glass && !backLayer && blurGlass ? _frontBlur : null,
      onTap: onTap,
      customActions: customActions,
      child: child,
    );
  }
}

class AppCheckRow extends StatelessWidget {
  const AppCheckRow({
    super.key,
    required this.check,
    required this.onTap,
    this.onAction,
    this.onLongPress,
    this.selected,
    this.grouped = false,
  });

  final CheckSummary check;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final VoidCallback? onLongPress;
  final bool? selected;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      checked: selected,
      child: AppPressableSurface(
        color: selected == true ? c.surfaceSelected : c.surfaceCard,
        border: grouped ? BorderSide.none : BorderSide(color: c.borderSubtle),
        radius: grouped ? 0 : DsShape.radiusXl,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s16, 16, DsSpace.s16, 18),
          child: Row(
            children: [
              Expanded(
                child: _CheckContent(check: check, onAction: onAction),
              ),
              if (selected case final checked?) ...[
                const SizedBox(width: DsSpace.s8),
                AppSelectionCheckbox(checked: checked),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckContent extends StatelessWidget {
  const _CheckContent({
    required this.check,
    this.onAction,
    this.home = false,
    this.compact = false,
    this.glass = false,
  });

  final CheckSummary check;
  final VoidCallback? onAction;
  final bool home;
  final bool compact;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = DateUtils.isSameDay(check.createdAt, DateTime.now());
    final date = home && today ? 'Today' : check.dateLabel;
    final primary = glass ? c.textCheckGlassPrimary : c.textPrimary;
    final secondary = glass ? c.textCheckGlassSecondary : c.textSecondary;
    final meta = AppTextStyles.captionRegular.copyWith(color: secondary, letterSpacing: glass ? 0.25 : null);
    final fixedDivider = glass && _noteFor(check) == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                check.treatment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (home ? AppTextStyles.headline : AppTextStyles.rowTitle).copyWith(
                  color: primary,
                  letterSpacing: glass ? 0.15 : null,
                ),
              ),
            ),
            if (date.isNotEmpty) ...[
              SizedBox(width: home ? DsSpace.s12 : DsSpace.s8),
              Text(date, style: meta),
            ],
          ],
        ),
        if (check.meta.isNotEmpty) ...[
          SizedBox(height: home ? DsSpace.s2 : DsSpace.s4),
          Text(check.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
        ],
        SizedBox(height: home ? (compact && _noteFor(check) != null ? 4 : 14) : DsSpace.s4),
        _CheckStatus(
          check: check,
          onAction: onAction,
          home: home,
          compact: compact,
          primary: primary,
          secondary: secondary,
          coveredDot: glass ? c.statusCheckGlassCovered : null,
        ),
        if (check.bestPolicyName.isNotEmpty) ...[
          if (home) ...[
            if (fixedDivider) const SizedBox(height: 10) else const Spacer(),
            Divider(height: 1, thickness: 1, color: c.borderSubtle),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: DsSpace.s6),
          _PolicyCaption(name: check.bestPolicyName, extraPolicies: check.policyCount - 1, glass: glass),
          if (fixedDivider) const Spacer(),
        ],
      ],
    );
  }
}

String? _noteFor(CheckSummary check) => switch (check.issue) {
  CheckIssue.review => 'We’ll update this when it’s reviewed.',
  CheckIssue.invalidPrescription => 'Upload the doctor’s prescription and try again.',
  null when check.statusKind == CheckStatusKind.checking => 'You can leave. We’ll let you know.',
  null when check.statusKind == CheckStatusKind.failed => 'Something went wrong on our side.',
  _ => null,
};

class _CheckStatus extends StatelessWidget {
  const _CheckStatus({
    required this.check,
    required this.home,
    this.onAction,
    required this.compact,
    required this.primary,
    required this.secondary,
    this.coveredDot,
  });

  final CheckSummary check;
  final bool home;
  final bool compact;
  final VoidCallback? onAction;
  final Color primary;
  final Color secondary;
  final Color? coveredDot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final checking = check.statusKind == CheckStatusKind.checking;
    final failed = check.statusKind == CheckStatusKind.failed;
    final note = _noteFor(check);
    final action = switch (check.statusKind) {
      CheckStatusKind.verification => 'Answer 1 question',
      CheckStatusKind.failed when check.issue == null => 'Try again',
      _ => null,
    };
    final hasAction = action != null && onAction != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              if (checking)
                SizedBox.square(
                  dimension: DsSize.iconMd,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: c.buttonPrimary,
                    backgroundColor: c.borderSubtle,
                  ),
                )
              else if (check.issue == CheckIssue.review)
                Icon(AppIcons.hourglassMedium, size: home ? DsSize.iconLg : DsSize.iconMd, color: secondary)
              else if (failed)
                Icon(
                  AppIcons.warningCircle,
                  size: home ? DsSize.iconLg : DsSize.iconMd,
                  color: c.statusNotCovered,
                )
              else
                AppStatusDot(
                  kind: check.statusKind,
                  size: home ? DsSize.indicatorDot : DsSpace.s8,
                  color: check.statusKind == CheckStatusKind.covered ? coveredDot : null,
                ),
              SizedBox(width: home ? DsSpace.s8 : DsSpace.s6),
              Expanded(
                child: Text(
                  failed && check.issue == null ? 'Couldn’t check' : check.statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (home ? AppTextStyles.checkStatus : AppTextStyles.compactStatus).copyWith(
                    color: checking ? secondary : primary,
                  ),
                ),
              ),
              if (hasAction) ...[
                const SizedBox(width: DsSpace.s8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * .54),
                  child: AppPressable(
                    onTap: onAction,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (failed) ...[
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(AppIcons.arrowClockwise, size: DsSize.iconXs, color: c.textLink),
                            ),
                            const TextSpan(text: ' '),
                          ],
                          TextSpan(text: action),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppTextStyles.secondary.copyWith(
                        color: c.textLink,
                        fontWeight: AppTextStyles.semibold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: DsSpace.s2),
          Text(
            note,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.secondary.copyWith(color: secondary),
          ),
        ],
      ],
    );
  }
}

class _PolicyCaption extends StatelessWidget {
  const _PolicyCaption({required this.name, required this.extraPolicies, required this.glass});

  final String name;
  final int extraPolicies;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = glass ? c.textCheckGlassSecondary : c.textSecondary;
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 19,
          child: FittedBox(child: AppIllustration(AppIllustrationKind.policy)),
        ),
        const SizedBox(width: DsSpace.s8),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.secondary.copyWith(color: foreground, letterSpacing: glass ? 0.2 : null),
          ),
        ),
        if (extraPolicies > 0) ...[
          const SizedBox(width: DsSpace.s8),
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: glass ? c.borderSubtle : c.borderDivider)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              child: Text(
                '+$extraPolicies',
                maxLines: 1,
                style: AppTextStyles.chip.copyWith(color: foreground),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
