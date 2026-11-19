import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';

class CoverageInsightsScreen extends ConsumerWidget {
  const CoverageInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsState = ref.watch(analysisReportProvider);
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: const Text('Coverage Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Insights',
            onPressed: () {
              ref.read(analysisReportProvider.notifier).fetchAnalysisReports(isRefresh: true);
              ref.read(dashboardStatsProvider.notifier).fetchStats();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(analysisReportProvider.notifier).fetchAnalysisReports(isRefresh: true),
              ref.read(dashboardStatsProvider.notifier).fetchStats(),
            ]);
          },
          child: reportsState.when(
            data: (pagination) {
              final groups = pagination.docs;

              if (groups.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xxl, AppSpacing.page, AppSpacing.xxl),
                  children: [
                    ContentWidth(
                      child: EmptyState(
                        icon: Icons.insights_rounded,
                        title: 'No Coverage Insights Yet',
                        message:
                            'Analyze your first medical prescription against your insurance policy to unlock actionable coverage metrics, waiting-period insights, and claim trends.',
                        action: PrimaryButton(
                          label: 'Start New Analysis',
                          icon: Icons.add_rounded,
                          onPressed: () => context.push('/consent'),
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Compute aggregate stats from real analysis report rows
              final allPolicies = <PolicyReportRow>[];
              for (final g in groups) {
                allPolicies.addAll(g.policyReports);
              }

              int coveredCount = 0;
              int partialCount = 0;
              int notCoveredCount = 0;
              int verifyCount = 0;

              final providerCounts = <String, int>{};

              for (final pr in allPolicies) {
                final status = pr.overallStatus.trim().toLowerCase();
                if (status.contains('not covered') || status == 'rejected') {
                  notCoveredCount++;
                } else if (status.contains('partial')) {
                  partialCount++;
                } else if (status == 'needs verification') {
                  verifyCount++;
                } else if (status == 'covered' || status == 'approved' || status == 'likely covered') {
                  coveredCount++;
                }

                if (pr.displayName.isNotEmpty && pr.displayName != 'Policy') {
                  providerCounts[pr.displayName] = (providerCounts[pr.displayName] ?? 0) + 1;
                }
              }

              final totalItems = allPolicies.length;
              final coverageRate = totalItems > 0 ? ((coveredCount / totalItems) * 100).round() : 0;

              // Sort top providers
              final topProviders = providerCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
                child: ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header card
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: p.primarySoft,
                          borderRadius: AppRadius.lgAll,
                          border: Border.all(color: p.primary.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$coverageRate% Coverage Rate',
                                    style: context.text.headlineSmall?.copyWith(
                                      color: p.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Across $totalItems policy evaluations in ${groups.length} clinical analyses',
                                    style: context.text.bodySmall?.copyWith(color: p.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),

                      // Metric Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: 'Covered',
                              count: coveredCount,
                              tone: AppTone.success,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _MetricCard(
                              label: 'Partial',
                              count: partialCount,
                              tone: AppTone.warning,
                              icon: Icons.rule_rounded,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _MetricCard(
                              label: 'Not Covered',
                              count: notCoveredCount,
                              tone: AppTone.danger,
                              icon: Icons.cancel_outlined,
                            ),
                          ),
                          if (verifyCount > 0) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _MetricCard(
                                label: 'Verification',
                                count: verifyCount,
                                tone: AppTone.verify,
                                icon: Icons.fact_check_outlined,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.section),

                      // Breakdown bar
                      const SectionHeader(
                        title: 'Claim Outcome Distribution',
                        subtitle: 'Visual proportion of all policy evaluations',
                      ),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.pillAll,
                              child: SizedBox(
                                height: 12,
                                child: Row(
                                  children: [
                                    if (coveredCount > 0)
                                      Expanded(
                                        flex: coveredCount,
                                        child: Container(color: p.success.fg),
                                      ),
                                    if (partialCount > 0)
                                      Expanded(
                                        flex: partialCount,
                                        child: Container(color: p.warning.fg),
                                      ),
                                    if (notCoveredCount > 0)
                                      Expanded(
                                        flex: notCoveredCount,
                                        child: Container(color: p.danger.fg),
                                      ),
                                    if (verifyCount > 0)
                                      Expanded(
                                        flex: verifyCount,
                                        child: Container(color: p.verify.fg),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.xs,
                              children: [
                                _LegendDot(color: p.success.fg, label: 'Covered ($coveredCount)'),
                                _LegendDot(color: p.warning.fg, label: 'Partially Covered ($partialCount)'),
                                _LegendDot(color: p.danger.fg, label: 'Not Covered ($notCoveredCount)'),
                                if (verifyCount > 0)
                                  _LegendDot(color: p.verify.fg, label: 'Needs Verification ($verifyCount)'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),

                      // Top Insurance Providers
                      if (topProviders.isNotEmpty) ...[
                        const SectionHeader(
                          title: 'Most Analyzed Policies',
                          subtitle: 'Frequency of policy documents checked against your care',
                        ),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (int i = 0; i < topProviders.length && i < 3; i++) ...[
                                if (i > 0) Divider(height: 1, indent: 56, color: p.border),
                                ListTile(
                                  dense: true,
                                  leading: IconTile(icon: Icons.shield_outlined, tone: AppTone.brand, size: 36),
                                  title: Text(
                                    topProviders[i].key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleSmall,
                                  ),
                                  trailing: Text(
                                    '${topProviders[i].value} ${topProviders[i].value == 1 ? 'time' : 'times'}',
                                    style: context.text.labelMedium?.copyWith(color: p.primary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.section),
                      ],

                      // Smart Advisory Tips
                      const SectionHeader(
                        title: 'Claim Preparation Insights',
                        subtitle: 'Key rules derived from health insurance adjudication',
                      ),
                      _AdvisoryCard(
                        icon: Icons.timeline_rounded,
                        tone: AppTone.brand,
                        title: 'Policy Continuity is Critical',
                        description:
                            'Maintain uninterrupted policy renewals. Breaks in coverage reset initial 30-day and 24-month waiting periods for specified ailments.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _AdvisoryCard(
                        icon: Icons.medical_services_outlined,
                        tone: AppTone.info,
                        title: 'Specific Clinical Diagnosis',
                        description:
                            'Insurance claims evaluate coverage based on formal diagnoses rather than generic symptom descriptions. Always ensure clinical notes are detailed.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _AdvisoryCard(
                        icon: Icons.account_balance_wallet_outlined,
                        tone: AppTone.warning,
                        title: 'Sub-limits & Co-payments',
                        description:
                            'Even for covered procedures, policies frequently apply room-rent caps and proportion deductions if treatment exceeds base category allowances.',
                      ),
                      const SizedBox(height: AppSpacing.section),

                      // Quick Action
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/reports'),
                              icon: const Icon(Icons.assignment_outlined, size: 18),
                              label: const Text('All Reports'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => context.push('/consent'),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('New Analysis'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              );
            },
            loading: () => const LoadingState(message: 'Generating coverage insights…'),
            error: (err, stack) => ErrorState(
              title: 'Couldn\'t load coverage insights',
              message: friendlyErrorMessage(err),
              onRetry: () => ref.read(analysisReportProvider.notifier).fetchAnalysisReports(isRefresh: true),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int count;
  final AppTone tone;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.count,
    required this.tone,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = p.tone(tone);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: t.fg, size: 20),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: context.text.bodySmall?.copyWith(fontSize: 12)),
      ],
    );
  }
}

class _AdvisoryCard extends StatelessWidget {
  final IconData icon;
  final AppTone tone;
  final String title;
  final String description;

  const _AdvisoryCard({
    required this.icon,
    required this.tone,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, tone: tone, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: context.text.bodyMedium?.copyWith(
                    color: p.textSecondary,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
