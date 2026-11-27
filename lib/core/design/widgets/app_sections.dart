import 'package:flutter/material.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';

/// A single rounded surface for adjacent list rows.
class AppRowGroup extends StatelessWidget {
  const AppRowGroup({super.key, required this.rows, this.onSheet = false});

  final List<Widget> rows;
  final bool onSheet;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = onSheet
        ? DsShape.shape(0)
        : DsShape.shape(DsShape.radiusXl, side: BorderSide(color: c.borderSubtle));
    return Container(
      foregroundDecoration: ShapeDecoration(shape: shape),
      decoration: ShapeDecoration(
        color: onSheet ? c.surfaceCardRaised : c.surfaceCard,
        shape: onSheet ? shape : DsShape.shape(DsShape.radiusXl),
      ),
      clipBehavior: onSheet ? Clip.none : Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0)
              Divider(height: 1, thickness: 1, color: onSheet ? c.borderDivider : c.borderSubtle),
            row,
          ],
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, style: AppTextStyles.headline.copyWith(color: context.colors.textPrimary)),
        ),
      ),
      if (onSeeAll case final onTap?)
        AppLink(label: 'See all', trailing: AppIcons.caretRight, onPressed: onTap),
    ],
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.illustration,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final AppIllustrationKind illustration;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DsSpace.cardPadding),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIllustration(illustration),
        const SizedBox(height: DsSpace.s12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.headline.copyWith(color: context.colors.textPrimary),
        ),
        const SizedBox(height: DsSpace.s12),
        AppButton(label: actionLabel, onPressed: onAction),
      ],
    ),
  );
}

enum AppSkeletonKind { card, row, documentCard }

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, required this.kind});

  final AppSkeletonKind kind;

  @override
  Widget build(BuildContext context) {
    final document = kind == AppSkeletonKind.documentCard;
    final row = kind == AppSkeletonKind.row;
    final c = context.colors;
    final block = DecoratedBox(
      decoration: ShapeDecoration(
        shape: DsShape.shape(row ? DsShape.radiusLg : DsShape.radiusXl),
        color: c.surfaceCardSubtle,
        shadows: const [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (row) ...[
              _SkeletonBar(width: DsSize.controlSm, height: DsSize.controlSm),
              const SizedBox(width: DsSpace.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SkeletonBar(width: DsSpace.s64, height: DsSpace.s12),
                  const SizedBox(height: DsSpace.s8),
                  _SkeletonBar(width: DsSpace.s40, height: document ? DsSpace.s24 : DsSpace.s8),
                  if (kind == AppSkeletonKind.card) ...[
                    const SizedBox(height: DsSpace.s24),
                    const _SkeletonBar(width: DsSpace.s64, height: DsSpace.s16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return ExcludeSemantics(
      child: document ? AspectRatio(aspectRatio: DsSize.documentCardAspect, child: block) : block,
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: context.colors.surfacePressed,
        shape: DsShape.shape(DsShape.radiusXs, side: BorderSide(color: context.colors.borderSubtle)),
      ),
    ),
  );
}

enum AppInlineBannerKind { info, offline, error }

class AppInlineBanner extends StatelessWidget {
  const AppInlineBanner({super.key, required this.kind, required this.message, this.title, this.onRetry});

  final AppInlineBannerKind kind;
  final String message;
  final String? title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, ink, fill) = switch (kind) {
      AppInlineBannerKind.info => (AppIcons.info, c.iconActive, c.surfaceSelected),
      AppInlineBannerKind.offline => (AppIcons.wifiSlash, c.iconDefault, c.surfaceCardSubtle),
      AppInlineBannerKind.error => (AppIcons.warning, c.statusNotCovered, c.statusNotCoveredBackground),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(color: fill, shape: DsShape.shape(DsShape.radiusMd)),
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: DsSize.iconMd, color: ink),
                const SizedBox(width: DsSpace.s8),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title case final heading?) ...[
                          Text(heading, style: AppTextStyles.subheadStrong.copyWith(color: c.textPrimary)),
                          const SizedBox(height: DsSpace.s4),
                        ],
                        Text(message, style: AppTextStyles.label.copyWith(color: c.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry case final retry?) AppLink(label: 'Retry', onPressed: retry),
          ],
        ),
      ),
    );
  }
}

class AppStepIndicator extends StatelessWidget {
  const AppStepIndicator({super.key, required this.step, this.total = 2, this.leading, this.trailing})
    : assert(total > 0),
      assert(step > 0 && step <= total);

  final int step;
  final int total;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = '$step of $total';
    if (leading != null) {
      return Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Row(children: [leading!, const Spacer(), ?trailing]),
              Semantics(
                label: 'Step $label',
                excludeSemantics: true,
                child: Text(label, style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.s8),
          Row(
            spacing: DsSpace.s6,
            children: [
              for (var i = 0; i < total; i++)
                Expanded(
                  child: Container(
                    height: DsSpace.s4,
                    decoration: ShapeDecoration(
                      color: i < step ? c.textPrimary : c.borderSubtle,
                      shape: DsShape.shape(DsShape.radiusFull),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }
    return Semantics(
      label: 'Step $label',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTextStyles.label.copyWith(color: c.textSecondary)),
            const SizedBox(height: DsSpace.s4),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s4,
              children: [
                for (var i = 0; i < total; i++)
                  SizedBox(
                    width: DsSpace.s12,
                    height: DsSpace.s4,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: i < step ? c.iconActive : c.borderStrong,
                        shape: DsShape.shape(DsShape.radiusFull),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
