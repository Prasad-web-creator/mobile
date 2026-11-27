import 'package:claimsupport/core/localization/localization.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:claimsupport/core/localization/translation_mapper.dart';
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

  static double heightFor(BuildContext context, {bool includesNote = false}) {
    final l10n = context.l10n;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    double lineHeight(String text, TextStyle style) {
      painter.text = TextSpan(text: text, style: style);
      painter.layout();
      return painter.height;
    }

    final title = lineHeight(l10n.sharedPrescription, AppTextStyles.headline);
    final meta = lineHeight(
      l10n.sharedForPatient(l10n.sharedYou),
      AppTextStyles.captionRegular,
    );
    final status = lineHeight(
      l10n.sharedFullyCovered,
      AppTextStyles.checkStatus,
    );
    final caption = lineHeight(l10n.sharedPolicy, AppTextStyles.secondary);
    final note = includesNote
        ? 2 + lineHeight(l10n.sharedReviewLater, AppTextStyles.secondary)
        : 0.0;
    painter.dispose();

    // Include the card ring, insets, divider, spacing, and the tallest possible
    // one-line status/action and caption. The stack uses the same box height.
    final minimum =
        32 +
        title * (l10n.localeName == 'ta' ? 2 : 1) +
        2 +
        meta +
        14 +
        status.clamp(24, double.infinity) +
        note +
        21 +
        caption.clamp(21, double.infinity) +
        4;
    return minimum.clamp(158, double.infinity).ceilToDouble();
  }

  static double stackHeight(
    BuildContext context,
    Iterable<CheckSummary> checks,
  ) => heightFor(
    context,
    includesNote: checks.any((check) => _noteFor(check, context.l10n) != null),
  );

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
                : heightFor(
                        context,
                        includesNote: _noteFor(check, context.l10n) != null,
                      ) -
                      2,
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

  static final _frontBlur = ImageFilter.blur(
    sigmaX: DsEffect.checkCardBlur,
    sigmaY: DsEffect.checkCardBlur,
  );

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
      color: glass && backLayer
          ? c.surfaceCard.withValues(alpha: 0.35)
          : surfaceColor ?? c.surfaceCard,
      border: BorderSide(color: glass ? c.borderCheckGlass : c.borderSubtle),
      gradient: glass && !backLayer
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.surfaceCheckGlassTop,
                c.surfaceCheckGlassTop,
                c.surfaceCard,
              ],
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
    final l10n = context.l10n;
    final createdAt = check.createdAt;
    final date = home && today
        ? l10n.sharedToday
        : createdAt == null || l10n.localeName == 'en'
        ? check.dateLabel
        : formatLocalizedDate(
            l10n,
            createdAt,
            pattern: today ? 'h:mm a' : 'd MMM yyyy',
          );
    final patient = check.patientName == 'you'
        ? l10n.sharedYou
        : check.patientName;
    final displayMeta = l10n.localeName == 'en'
        ? check.meta
        : [
            if (patient.isNotEmpty) l10n.sharedForPatient(patient),
            if (check.policyCount > 1)
              l10n.sharedPoliciesCompared(check.policyCount),
          ].join(' · ');
    final primary = glass ? c.textCheckGlassPrimary : c.textPrimary;
    final secondary = glass ? c.textCheckGlassSecondary : c.textSecondary;
    final meta = AppTextStyles.captionRegular.copyWith(
      color: secondary,
      letterSpacing: glass ? 0.25 : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  check.displayTreatment(l10n),
                  maxLines: home && l10n.localeName == 'ta' ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (home ? AppTextStyles.headline : AppTextStyles.rowTitle)
                          .copyWith(
                            color: primary,
                            letterSpacing: glass ? 0.15 : null,
                          ),
                ),
              ),
              if (date.isNotEmpty) ...[
                SizedBox(width: home ? DsSpace.s12 : DsSpace.s8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * .32,
                  ),
                  child: Text(
                    date,
                    style: meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (displayMeta.isNotEmpty) ...[
          SizedBox(height: home ? DsSpace.s2 : DsSpace.s4),
          Text(
            displayMeta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: meta,
          ),
        ],
        SizedBox(
          height: home
              ? (compact && _noteFor(check, context.l10n) != null ? 4 : 14)
              : DsSpace.s4,
        ),
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
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: c.borderSubtle),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: DsSpace.s6),
          _PolicyCaption(
            name: check.bestPolicyName == "Policy"
                ? l10n.sharedPolicy
                : check.bestPolicyName,
            extraPolicies: check.policyCount - 1,
            glass: glass,
          ),
        ],
      ],
    );
  }
}

String? _noteFor(CheckSummary check, AppLocalizations l10n) =>
    switch (check.issue) {
      CheckIssue.review => l10n.sharedReviewLater,
      CheckIssue.invalidPrescription => l10n.sharedUploadPrescriptionRetry,
      null when check.statusKind == CheckStatusKind.checking =>
        l10n.sharedCanLeave,
      null when check.statusKind == CheckStatusKind.failed =>
        l10n.sharedFailureOnOurSide,
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
    final note = _noteFor(check, context.l10n);
    final action = switch (check.statusKind) {
      CheckStatusKind.verification => context.l10n.sharedAnswerOne,
      CheckStatusKind.failed when check.issue == null =>
        context.l10n.sharedTryAgain,
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
                Icon(
                  AppIcons.hourglassMedium,
                  size: home ? DsSize.iconLg : DsSize.iconMd,
                  color: secondary,
                )
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
                  color: check.statusKind == CheckStatusKind.covered
                      ? coveredDot
                      : null,
                ),
              SizedBox(width: home ? DsSpace.s8 : DsSpace.s6),
              Expanded(
                child: Text(
                  failed && check.issue == null
                      ? context.l10n.sharedCouldNotCheck
                      : localizedCheckStatus(context.l10n, check.statusLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (home
                              ? AppTextStyles.checkStatus
                              : AppTextStyles.compactStatus)
                          .copyWith(color: checking ? secondary : primary),
                ),
              ),
              if (hasAction) ...[
                const SizedBox(width: DsSpace.s8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * .54,
                  ),
                  child: AppPressable(
                    onTap: onAction,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (failed) ...[
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                AppIcons.arrowClockwise,
                                size: DsSize.iconXs,
                                color: c.textLink,
                              ),
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
  const _PolicyCaption({
    required this.name,
    required this.extraPolicies,
    required this.glass,
  });

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
            style: AppTextStyles.secondary.copyWith(
              color: foreground,
              letterSpacing: glass ? 0.2 : null,
            ),
          ),
        ),
        if (extraPolicies > 0) ...[
          const SizedBox(width: DsSpace.s8),
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(
                  color: glass ? c.borderSubtle : c.borderDivider,
                ),
              ),
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
