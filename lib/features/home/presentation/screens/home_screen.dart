import 'package:claimsupport/core/localization/localization.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:claimsupport/features/checks/data/check_jobs.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/core/design/widgets/app_placeholder_pulse.dart';
import 'package:claimsupport/core/network/server_error_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/check_steps.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/core/design/widgets/floating_nav_bar.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/home_background.dart';
import 'package:claimsupport/core/routing/app_shell.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart'
    show friendlyErrorMessage;
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_stack.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_card.dart';
import 'package:claimsupport/features/home/presentation/widgets/home_entrance.dart';

/// Home (Figma "Home v4": no data 44:16 / 44:92, with data 45:116 / 45:212).
///
/// No checks yet → the context.l10n.sharedKnowYourCover empty state.
/// Otherwise → "Hi, {name}", the Recent checks stack and the Document cards.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static void startCheck(BuildContext context) => context.push('/check/new');

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(checkJobsProvider);
    ref.invalidate(homeChecksProvider);
    ref.invalidate(dashboardStatsProvider);
    await Future.wait([
      ref.read(homeChecksProvider.future),
      ref.read(dashboardStatsProvider.future),
    ]).catchError((_) => <Object>[]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final checks = ref.watch(homeChecksProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final user = ref.watch(authProvider).value;
    final cached = ref.watch(homeSnapshotProvider);
    final fullName = (user?.name ?? cached?.name ?? '').trim();
    final firstName = fullName.split(RegExp(r'\s+')).first;
    final currentChecks = checks.value ?? cached?.checks;
    final loading = checks.isLoading && currentChecks == null;
    final hasChecks = currentChecks?.isNotEmpty == true;
    final error = checks.error ?? stats.error;
    final serverMessage = serverErrorMessage(error, l10n: context.l10n);
    final showingSaved = serverMessage != null && currentChecks != null;
    final banner = error == null
        ? null
        : AppInlineBanner(
            kind: showingSaved
                ? AppInlineBannerKind.offline
                : AppInlineBannerKind.error,
            title: serverMessage == null
                ? null
                : context.l10n.sharedCannotConnect,
            message: showingSaved
                ? context.l10n.sharedShowingSavedChecks(serverMessage)
                : serverMessage ??
                      friendlyErrorMessage(error, l10n: context.l10n),
            onRetry: () => _refresh(ref),
          );
    final reduced = DsMotion.reduced(context);
    final cardHeight = AppCheckCard.stackHeight(
      context,
      currentChecks ?? const [],
    );
    void openHistory() => context.go(AppRootNavigation.historyPath);
    final docs = _DocumentCards(
      prescriptions:
          stats.value?.totalPrescriptions ?? cached?.counts?.prescriptions,
      policies: stats.value?.totalPolicies ?? cached?.counts?.policies,
    );

    final showRecent = loading || hasChecks;
    final showError = checks.hasError && currentChecks == null;
    final layout = showRecent ? 'recent' : (showError ? 'error' : 'empty');
    final content = Column(
      key: ValueKey(layout),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRecent) ...[
          HomeReveal(
            delay: 100,
            duration: 320,
            rise: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
                  child: AppSectionHeader(
                    title: context.l10n.sharedRecentChecks,
                  ),
                ),
                const SizedBox(height: DsSpace.s12),
                SizedBox(
                  height: cardHeight + 28,
                  child: AnimatedSwitcher(
                    duration: reduced ? Duration.zero : DsMotion.base,
                    layoutBuilder: _crossfadeLayout,
                    child: loading
                        ? _HomeCheckPlaceholder(cardHeight: cardHeight)
                        : AppCheckStack(
                            checks: currentChecks!,
                            cardHeight: cardHeight,
                            glass: true,
                            onOpen: (CheckSummary check) =>
                                context.push(check.route, extra: check.group),
                            onAction: (check) {
                              if (check.actionRoute case final route?) {
                                context.push(route, extra: check.group);
                              }
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpace.s4),
          HomeReveal(
            delay: 260,
            duration: 200,
            child: CheckStackViewAll(onTap: openHistory),
          ),
          const SizedBox(height: 18),
          HomeReveal(
            delay: 280,
            duration: 320,
            rise: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
              child: AppSectionHeader(title: context.l10n.sharedDocuments),
            ),
          ),
          const SizedBox(height: 14),
          docs,
        ] else if (!showError) ...[
          HomeReveal(
            delay: 100,
            duration: 320,
            rise: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.sharedKnowYourCover,
                  style: AppTextStyles.largeTitle.copyWith(
                    color: c.textOnGradient,
                  ),
                ),
                const SizedBox(height: DsSpace.sectionGap),
                const CheckSteps(),
                const SizedBox(height: DsSpace.s24),
                AppButton(
                  style: AppButtonStyle.secondary,
                  label: context.l10n.sharedFirstCheck,
                  haptic: true,
                  onPressed: () => startCheck(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpace.s24),
          docs,
        ],
        if (banner != null) ...[const SizedBox(height: DsSpace.s12), banner],
      ],
    );

    final navClearance = FloatingNavBar.scrollClearance(context);
    return RootShell(
      useHomeBackgroundColor: true,
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: Builder(
          builder: (bodyContext) {
            // Scaffold's extended body exposes the navigation dock height.
            final dockHeight = MediaQuery.paddingOf(bodyContext).bottom;
            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.only(
                bottom: math.max(navClearance, dockHeight) + DsSpace.sectionGap,
              ),
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: HomeReveal(
                        delay: 0,
                        duration: 350,
                        child: HomeBackground(),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        DsSpace.s16,
                        DsSpace.screenTop(context),
                        DsSpace.s16,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HomeReveal(
                            delay: 40,
                            duration: 300,
                            rise: 8,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DsSpace.s4,
                              ),
                              child: _Header(
                                firstName: firstName,
                                fullName: fullName,
                              ),
                            ),
                          ),
                          const _ResumeLinks(),
                          SizedBox(
                            height: showRecent
                                ? DsSpace.s20
                                : DsSpace.sectionGap,
                          ),
                          AnimatedSwitcher(
                            duration: reduced
                                ? Duration.zero
                                : const Duration(milliseconds: 250),
                            layoutBuilder: _crossfadeLayout,
                            child: content,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Widget _crossfadeLayout(Widget? current, List<Widget> previous) => Stack(
  alignment: Alignment.topCenter,
  fit: StackFit.passthrough,
  clipBehavior: Clip.none,
  children: [
    for (final child in previous)
      IgnorePointer(child: ExcludeSemantics(child: child)),
    ?current,
  ],
);

class _HomeCheckPlaceholder extends StatelessWidget {
  const _HomeCheckPlaceholder({required this.cardHeight});

  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final entrance = HomeEntrance.maybeOf(context);
    Widget card(int layer) {
      final position =
          layer * (entrance?.spreadAt(entrance.progress.value) ?? 1);
      return Transform.translate(
        offset: Offset(0, position * 12),
        child: Transform.scale(
          alignment: Alignment.topCenter,
          scale: 1 - position * 0.06,
          child: SizedBox(
            height: cardHeight / (1 - position * 0.06),
            width: double.infinity,
            child: AppCheckCardSurface(
              glass: true,
              backLayer: layer != 0,
              blurGlass: false,
              child: layer == 0
                  ? Padding(
                      padding: const EdgeInsets.all(DsSpace.s16),
                      child: AppPlaceholderPulse(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final (width, height) in [
                              (0.63, 16.0),
                              (0.4, 12.0),
                              (0.46, 18.0),
                              (0.55, 12.0),
                            ])
                              FractionallySizedBox(
                                widthFactor: width,
                                child: SizedBox(
                                  height: height,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color:
                                          c.surfaceCardSubtle == c.surfaceCard
                                          ? c.surfacePressed
                                          : c.surfaceCardSubtle,
                                      shape: DsShape.shape(DsShape.radiusXs),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    Widget stack() =>
        Stack(clipBehavior: Clip.none, children: [card(2), card(1), card(0)]);
    return RepaintBoundary(
      child: ExcludeSemantics(
        child: entrance == null
            ? stack()
            : AnimatedBuilder(
                animation: entrance.progress,
                builder: (context, _) => stack(),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.firstName, required this.fullName});

  final String firstName;
  final String fullName;

  String get _initials {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final greeting = firstName.isEmpty
        ? context.l10n.sharedHi
        : context.l10n.sharedGreeting(firstName);
    return Row(
      children: [
        Expanded(
          child: Text(
            greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.largeTitle.copyWith(color: c.textOnGradient),
          ),
        ),
        const SizedBox(width: DsSpace.s8),
        AppGlassAvatar(
          initials: _initials,
          onPressed: () => context.push('/profile'),
        ),
      ],
    );
  }
}

class _DocumentCards extends StatelessWidget {
  const _DocumentCards({required this.prescriptions, required this.policies});

  final int? prescriptions;
  final int? policies;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: HomeReveal(
            delay: 280,
            duration: 320,
            rise: 12,
            child: AppDocumentCard(
              type: DocumentCardType.prescription,
              count: prescriptions,
              onTap: () => context.push('/documents?tab=prescriptions'),
            ),
          ),
        ),
        const SizedBox(width: DsSpace.gridGap),
        Expanded(
          child: HomeReveal(
            delay: 320,
            duration: 320,
            rise: 12,
            child: AppDocumentCard(
              type: DocumentCardType.policy,
              count: policies,
              onTap: () => context.push('/documents?tab=policies'),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Continue draft" / "Resume last analysis" from the old Home, kept so the
/// feature isn't lost.
///
/// TODO(design): not in Figma. Placeholder text links until Avinash designs it.
class _ResumeLinks extends StatelessWidget {
  const _ResumeLinks();

  @override
  Widget build(BuildContext context) {
    final prefs = SharedPrefs.maybeInstance;
    final resumeJob = prefs?.getString(SharedPrefs.analysisResumeKey);
    final draft = prefs?.getString(SharedPrefs.analysisDraftKey);
    final links = <(String, String)>[
      if (draft != null && draft != resumeJob)
        (context.l10n.sharedResumeDraft, '/upload?resume=true'),
      if (resumeJob != null)
        (
          context.l10n.sharedResumeCheck,
          '/check/processing/${Uri.encodeComponent(resumeJob)}',
        ),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.s8),
      child: Wrap(
        spacing: DsSpace.s8,
        children: [
          for (final (label, route) in links)
            AppLink(label: label, onPressed: () => context.push(route)),
        ],
      ),
    );
  }
}
