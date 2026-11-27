import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/core/design/widgets/app_design_surface.dart';
import 'package:flutter/services.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';

/// Shared header for a root page. Home can supply its existing greeting layout.
class RootHeader extends StatelessWidget {
  const RootHeader({super.key, required this.title, this.avatar, this.action});

  final String title;
  final Widget? avatar;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      DsSpace.screenPadding,
      DsSpace.screenTop(context),
      DsSpace.screenPadding,
      DsSpace.s12,
    ),
    child: Row(
      children: [
        Expanded(child: _ScreenTitle(title)),
        ?avatar,
        ?action,
      ],
    ),
  );
}

class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.body,
    this.navigation,
    this.title,
    this.avatar,
    this.useHomeBackgroundColor = false,
  });

  static const systemNavigationStyle = SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  final Widget body;
  final Widget? navigation;
  final String? title;
  final Widget? avatar;
  final bool useHomeBackgroundColor;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  bool _navVisible = true;
  double _travel = 0;

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0 || event.metrics.axis != Axis.vertical) return false;
    if (event is ScrollStartNotification || event is ScrollEndNotification) {
      _travel = 0;
    }
    if (event is ScrollUpdateNotification && event.dragDetails != null) {
      final delta = event.scrollDelta ?? 0;
      if (delta * _travel < 0) _travel = 0;
      _travel += delta;
      final atTop = event.metrics.pixels <= event.metrics.minScrollExtent;
      if (!_navVisible && (atTop || _travel < -DsSpace.s8)) {
        setState(() => _navVisible = true);
      } else if (_navVisible && !atTop && _travel > DsSpace.s8) {
        setState(() => _navVisible = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final reduced = DsMotion.reduced(context);
    final title = widget.title;
    return _GradientPage(
      extendBody: true,
      useHomeBackgroundColor: widget.useHomeBackgroundColor,
      systemNavigationStyle: RootShell.systemNavigationStyle,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: title == null
            ? widget.body
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RootHeader(title: title, avatar: widget.avatar),
                  Expanded(child: widget.body),
                ],
              ),
      ),
      bottom: widget.navigation == null
          ? null
          : AnimatedSlide(
              offset: _navVisible || reduced ? Offset.zero : const Offset(0, 1),
              duration: reduced ? Duration.zero : DsMotion.base,
              curve: DsMotion.baseCurve,
              child: AnimatedOpacity(
                opacity: _navVisible || !reduced ? 1 : 0,
                duration: DsMotion.fast,
                child: ExcludeFocus(
                  excluding: !_navVisible,
                  child: ExcludeSemantics(
                    excluding: !_navVisible,
                    child: IgnorePointer(ignoring: !_navVisible, child: widget.navigation!),
                  ),
                ),
              ),
            ),
    );
  }
}

/// The body supplies its own scrollable. Its primary controller is coordinated
/// with the large title so existing lists can keep pagination and refresh.
class PushedShell extends StatefulWidget {
  const PushedShell({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.action,
    this.titleMaxLines,
    this.subtitle,
    this.selectionHeader,
    this.showTitleInSelection = false,
    this.bottom,
    this.titleStyle,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final Widget? action;
  final int? titleMaxLines;
  final String? subtitle;
  final Widget? selectionHeader;
  final bool showTitleInSelection;
  final Widget? bottom;
  final TextStyle? titleStyle;

  @override
  State<PushedShell> createState() => _PushedShellState();
}

class _PushedShellState extends State<PushedShell> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = DsSpace.screenTop(context);
    final c = context.colors;
    return _GradientPage(
      bottom: widget.bottom,
      body: Column(
        children: [
          if (widget.selectionHeader case final header?)
            header
          else
            AnimatedBuilder(
              animation: _scroll,
              builder: (context, _) {
                final collapsed =
                    _scroll.hasClients &&
                    _scroll.position.hasContentDimensions &&
                    _scroll.position.maxScrollExtent > 0 &&
                    _scroll.offset >= _scroll.position.maxScrollExtent;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: DsMotion.base,
                        curve: DsMotion.baseCurve,
                        opacity: collapsed ? 1 : 0,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: DsEffect.navBlur, sigmaY: DsEffect.navBlur),
                            child: ColoredBox(color: c.surfaceNavBar),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        DsSpace.screenPadding,
                        top,
                        DsSpace.screenPadding,
                        DsSpace.s8,
                      ),
                      child: Row(
                        children: [
                          AppIconButton(
                            icon: AppIcons.caretLeft,
                            label: MaterialLocalizations.of(context).backButtonTooltip,
                            onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                          ),
                          const SizedBox(width: DsSpace.s8),
                          Expanded(
                            child: ExcludeSemantics(
                              excluding: !collapsed,
                              child: AnimatedOpacity(
                                duration: DsMotion.base,
                                curve: DsMotion.baseCurve,
                                opacity: collapsed ? 1 : 0,
                                child: Text(
                                  widget.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.headline.copyWith(color: c.textPrimary),
                                ),
                              ),
                            ),
                          ),
                          ?widget.action,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: NestedScrollView(
                controller: _scroll,
                headerSliverBuilder: (context, _) => [
                  if (widget.selectionHeader == null || widget.showTitleInSelection)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DsSpace.screenPadding,
                          0,
                          DsSpace.screenPadding,
                          DsSpace.s12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ScreenTitle(
                              widget.title,
                              maxLines: widget.titleMaxLines,
                              style: widget.titleStyle,
                            ),
                            if (widget.subtitle case final subtitle? when subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
                body: SafeArea(top: false, bottom: widget.bottom == null, child: widget.body),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FlowShell extends StatelessWidget {
  const FlowShell({
    super.key,
    required this.body,
    required this.onClose,
    this.title,
    this.step,
    this.stepCount = 2,
    this.action,
    this.bottomAction,
    this.backButton = false,
  });

  final Widget body;
  final VoidCallback onClose;
  final String? title;
  final int? step;
  final int stepCount;
  final Widget? action;
  final Widget? bottomAction;
  final bool backButton;

  @override
  Widget build(BuildContext context) {
    final bottom = bottomAction;
    final close = AppIconButton(
      icon: backButton ? AppIcons.caretLeft : AppIcons.close,
      label: backButton
          ? MaterialLocalizations.of(context).backButtonTooltip
          : MaterialLocalizations.of(context).closeButtonTooltip,
      onPressed: onClose,
    );
    return _GradientPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              DsSpace.screenPadding,
              DsSpace.screenTop(context),
              DsSpace.screenPadding,
              DsSpace.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (step case final number?)
                  AppStepIndicator(step: number, total: stepCount, leading: close, trailing: action)
                else
                  Row(
                    children: [
                      close,
                      if (title != null) ...[
                        const SizedBox(width: DsSpace.s8),
                        Expanded(
                          child: Text(
                            title!,
                            style: AppTextStyles.headline.copyWith(color: context.colors.textOnGradient),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      ?action,
                    ],
                  ),
                if (step != null && title != null) ...[
                  const SizedBox(height: DsSpace.s16),
                  _ScreenTitle(
                    title!,
                    style: AppTextStyles.title.copyWith(
                      fontSize: 28,
                      height: 32 / 28,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: SafeArea(top: false, bottom: bottomAction == null, child: body),
            ),
          ),
        ],
      ),
      bottom: bottom == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.backgroundPage,
                border: Border(top: BorderSide(color: context.colors.borderSubtle)),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(top: DsSpace.s12, bottom: DsSpace.s16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.screenPadding),
                  child: bottom,
                ),
              ),
            ),
    );
  }
}

class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.body,
    this.footer,
    this.showClose = false,
    this.subtitle,
    this.artwork,
  });

  final String title;
  final Widget body;
  final Widget? footer;
  final bool showClose;
  final String? subtitle;
  final AppIllustrationKind? artwork;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required WidgetBuilder bodyBuilder,
    WidgetBuilder? footerBuilder,
    bool showClose = false,
    String? subtitle,
    AppIllustrationKind? artwork,
  }) => showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => AppDesignSurface(
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Builder(
          builder: (context) => AppSheet(
            title: title,
            body: bodyBuilder(context),
            footer: footerBuilder?.call(context),
            showClose: showClose,
            subtitle: subtitle,
            artwork: artwork,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final art = artwork;
    final sheet = Material(
      color: context.colors.surfaceCardRaised,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DsShape.radiusXl)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: art == null ? DsSpace.s16 : 34),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            DsSpace.screenPadding,
            DsSpace.s8,
            DsSpace.screenPadding,
            MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: DsSpace.s32,
                  height: DsSpace.s4,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: context.colors.borderStrong,
                      shape: DsShape.shape(DsShape.radiusFull),
                    ),
                  ),
                ),
              ),
              SizedBox(height: art == null ? DsSpace.s8 : 36),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: AppTextStyles.title.copyWith(color: context.colors.textPrimary),
                      ),
                    ),
                  ),
                  if (showClose)
                    AppIconButton(
                      icon: AppIcons.close,
                      label: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              if (subtitle case final text? when text.isNotEmpty) ...[
                const SizedBox(height: DsSpace.s4),
                Text(text, style: AppTextStyles.reportBody.copyWith(color: context.colors.textSecondary)),
              ],
              const SizedBox(height: DsSpace.s12),
              Flexible(child: SingleChildScrollView(child: body)),
              if (footer case final action?) ...[const SizedBox(height: DsSpace.s12), action],
            ],
          ),
        ),
      ),
    );
    if (art == null) return sheet;
    final c = context.colors;
    return Stack(
      children: [
        Padding(padding: const EdgeInsets.only(top: 36), child: sheet),
        PositionedDirectional(
          start: DsSpace.screenPadding,
          top: 0,
          child: SizedBox.square(
            dimension: 76,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: c.surfaceCardRaised,
                shape: DsShape.shape(22, side: BorderSide(color: c.borderDivider)),
                shadows: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.s12),
                child: FittedBox(child: AppIllustration(art)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientPage extends StatelessWidget {
  const _GradientPage({
    required this.body,
    this.bottom,
    this.extendBody = false,
    this.systemNavigationStyle,
    this.useHomeBackgroundColor = false,
  });

  final Widget body;
  final Widget? bottom;
  final bool extendBody;
  final SystemUiOverlayStyle? systemNavigationStyle;
  final bool useHomeBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final overlay = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    final navigationStyle =
        systemNavigationStyle ??
        overlay.copyWith(
          systemNavigationBarColor: context.colors.backgroundPage,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: navigationStyle.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: overlay.statusBarBrightness,
        statusBarIconBrightness: overlay.statusBarIconBrightness,
      ),
      child: AppDesignSurface(
        child: Scaffold(
          backgroundColor: useHomeBackgroundColor
              ? context.colors.backgroundHome
              : context.colors.backgroundPage,
          extendBody: extendBody,
          body: body,
          bottomNavigationBar: bottom,
        ),
      ),
    );
  }
}

class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle(this.title, {this.maxLines, this.style});

  final String title;
  final int? maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: style ?? AppTextStyles.largeTitle.copyWith(color: context.colors.textOnGradient),
    ),
  );
}
