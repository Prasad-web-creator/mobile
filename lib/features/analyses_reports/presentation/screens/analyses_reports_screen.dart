import 'package:claimsupport/core/localization/translation_mapper.dart';
import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_choices.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/floating_nav_bar.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/documents/presentation/saved_list_actions.dart';
import 'package:claimsupport/features/documents/presentation/saved_list_feedback.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AnalysesReportsScreen extends ConsumerStatefulWidget {
  const AnalysesReportsScreen({super.key});

  @override
  ConsumerState<AnalysesReportsScreen> createState() =>
      _AnalysesReportsScreenState();
}

typedef _ReportPage = PaginationResponse<AnalysisReportGroup>;

class _AnalysesReportsScreenState extends ConsumerState<AnalysesReportsScreen>
    with SavedListActions<AnalysesReportsScreen, AnalysisReportGroup> {
  AppCheckFilter _filter = AppCheckFilter.all;
  (_ReportPage, AppCheckFilter)? _filterSource;
  Future<_ReportPage>? _filtered;

  bool _matches(CheckSummary check, AppCheckFilter filter) {
    final kind = switch (filter) {
      AppCheckFilter.all => null,
      AppCheckFilter.covered => CheckStatusKind.covered,
      AppCheckFilter.partial => CheckStatusKind.partial,
      AppCheckFilter.notCovered => CheckStatusKind.notCovered,
      AppCheckFilter.verification => CheckStatusKind.verification,
    };
    if (kind == null) return true;
    final policies = check.policyResults;
    return policies.isEmpty
        ? check.statusKind == kind
        : policies.any(
            (policy) => CheckSummary.resultForPolicy(policy).$1 == kind,
          );
  }

  Future<_ReportPage> _matchingReports(
    _ReportPage first,
    AppCheckFilter filter,
    AnalysisReportNotifier notifier,
  ) async {
    final matches = <AnalysisReportGroup>[];
    var page = first;
    while (true) {
      matches.addAll(
        page.docs.where(
          (group) => _matches(CheckSummary.fromGroup(group), filter),
        ),
      );
      if (!page.hasNextPage || page.docs.isEmpty) break;
      page = await notifier.fetchPage(page.page + 1);
    }
    return PaginationResponse(
      docs: matches,
      totalDocs: matches.length,
      limit: first.limit,
      page: 1,
      totalPages: matches.isEmpty ? 0 : 1,
      hasPrevPage: false,
      hasNextPage: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisReportProvider);
    final notifier = ref.read(analysisReportProvider.notifier);
    final first = state.value ?? notifier.cachedPage;

    void startCheck() => context.push('/check/new');
    Future<void> refresh() async {
      if (listBusy) return;
      setState(() {
        resetList();
        _filterSource = null;
      });
      await notifier.fetchAnalysisReports(isRefresh: true);
    }

    Widget contents(
      _ReportPage? source,
      Future<_ReportPage> Function(int) fetch, {
      Object? filterError,
    }) => _buildList(
      context,
      source: source,
      fetch: fetch,
      isLoading:
          (state.isLoading && first == null) ||
          (first != null && source == null && filterError == null),
      error: filterError ?? state.error,
      hasSaved: first != null,
      startCheck: startCheck,
      refresh: refresh,
      delete: (ids) async {
        try {
          return await notifier.deleteReports(ids);
        } finally {
          if (mounted) {
            ref.invalidate(homeChecksProvider);
            ref.invalidate(dashboardStatsProvider);
          }
        }
      },
    );

    Widget body;
    if (first == null || _filter == AppCheckFilter.all) {
      body = contents(first, notifier.fetchAndKeepPage);
    } else {
      final key = (first, _filter);
      if (_filterSource != key) {
        _filterSource = key;
        _filtered = _matchingReports(first, _filter, notifier);
      }
      body = FutureBuilder(
        future: _filtered,
        builder: (context, snapshot) {
          final result = snapshot.connectionState == ConnectionState.done
              ? snapshot.data
              : null;
          return contents(
            result,
            notifier.fetchPage,
            filterError: snapshot.error,
          );
        },
      );
    }
    return RootShell(
      title: selecting ? null : context.l10n.analysisHistory,
      body: body,
      useHomeBackgroundColor: Theme.of(context).brightness == Brightness.dark,
    );
  }

  String _deletableId(AnalysisReportGroup group, CheckSummary check) =>
      check.statusKind == CheckStatusKind.checking ||
          group.status == 'waiting_for_user'
      ? ''
      : group.groupId;

  Widget _buildList(
    BuildContext context, {
    required _ReportPage? source,
    required Future<_ReportPage> Function(int) fetch,
    required bool isLoading,
    required Object? error,
    required bool hasSaved,
    required VoidCallback startCheck,
    required Future<void> Function() refresh,
    required Future<int> Function(List<String>) delete,
  }) {
    final page = source == null ? null : visiblePage(source);
    final byMonth = <String, List<(AnalysisReportGroup, CheckSummary)>>{};
    if (page != null) {
      final groups = page.docs.toList();
      final earliest = DateTime.fromMillisecondsSinceEpoch(0);
      groups.sort(
        (a, b) => (b.createdAt ?? earliest).compareTo(a.createdAt ?? earliest),
      );
      final format = DateFormat.yMMMM(
        dateFormatLocale(context.l10n.localeName),
      );
      final accountName = ref.watch(
        authProvider.select((state) => state.value?.name),
      );
      for (final group in groups) {
        final check = CheckSummary.fromGroup(group, accountName: accountName);
        final month = group.createdAt == null
            ? context.l10n.analysisDateUnavailable
            : format.format(group.createdAt!.toLocal());
        byMonth.putIfAbsent(month, () => []).add((group, check));
      }
    }

    final list = loadOnScroll(
      source: source,
      fetch: fetch,
      enabled: !isLoading && error == null && _filter == AppCheckFilter.all,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          key: ValueKey(_filter),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            0,
            DsSpace.s4,
            0,
            selecting
                ? DsSpace.s8
                : FloatingNavBar.scrollClearance(context) + DsSpace.sectionGap,
          ),
          children: [
            AppFilterChips(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpace.screenPadding,
              ),
              selected: _filter,
              onChanged: (filter) {
                if (_filter == filter || listBusy) return;
                setState(() {
                  resetList();
                  _filter = filter;
                });
              },
            ),
            const SizedBox(height: 22),
            ...<Widget>[
              if (error != null && !isLoading)
                SavedListError(
                  error: error,
                  offlineMessage: hasSaved
                      ? context.l10n.analysisOfflineSaved
                      : context.l10n.analysisOffline,
                  message: context.l10n.analysisLoadChecksFailed,
                  onRetry: refresh,
                ),
              if (page == null && isLoading) const SavedListSkeleton(),
              if (page != null && source != null) ...[
                if (page.docs.isEmpty && _filter == AppCheckFilter.all)
                  AppEmptyState(
                    illustration: AppIllustrationKind.prescription,
                    message: context.l10n.analysisNoChecks,
                    actionLabel: context.l10n.analysisStartCheck,
                    onAction: startCheck,
                  )
                else if (byMonth.isEmpty)
                  SavedListMessage(context.l10n.analysisNoChecksFilter),
                for (final entry in byMonth.entries) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: DsSpace.s4,
                    ),
                    child: Text(
                      entry.key,
                      style: AppTextStyles.captionStrong.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  AppRowGroup(
                    rows: [
                      for (final (group, check) in entry.value)
                        AppCheckRow(
                          grouped: true,
                          check: check,
                          onAction: selecting || check.actionRoute == null
                              ? null
                              : () => context.push(
                                  check.actionRoute!,
                                  extra: group,
                                ),
                          selected: itemSelection(_deletableId(group, check)),
                          onLongPress:
                              selecting || _deletableId(group, check).isEmpty
                              ? null
                              : () => beginSelection(check.id),
                          onTap:
                              selecting && _deletableId(group, check).isNotEmpty
                              ? () => toggleItem(check.id)
                              : () => context.push(check.route, extra: group),
                        ),
                    ],
                  ),
                  const SizedBox(height: DsSpace.s24),
                ],
                moreStatus(source, fetch),
              ],
            ].map(
              (child) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpace.screenPadding,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        if (selecting)
          selectionHeader(
            source,
            fetch,
            (group) => _deletableId(group, CheckSummary.fromGroup(group)),
          ),
        Expanded(child: list),
        if (selecting)
          selectionFooter(
            singular: 'check',
            plural: 'checks',
            isDocument: false,
            delete: delete,
          ),
      ],
    );
  }
}
