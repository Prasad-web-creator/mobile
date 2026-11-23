import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report.dart';
import 'package:claimsupport/features/dashboard/presentation/widgets/home_banner_ad.dart';
import 'package:claimsupport/features/dashboard/presentation/widgets/floating_banner_ad.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(dashboardStatsProvider.notifier).fetchStats();
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: ContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, 112),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Greeting(),
                        const SizedBox(height: AppSpacing.xl),
                        _StartAnalysisCard(onStart: () => context.push('/consent')),
                        const SizedBox(height: AppSpacing.xl),

                        // Google AdMob banner (collapses with its spacing when no ad loads)
                        const HomeBannerAd(),

                        Consumer(
                          builder: (context, ref, child) {
                            final dashboardState = ref.watch(dashboardStatsProvider);
                            return dashboardState.when(
                              data: (stats) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SectionHeader(
                                    title: 'Your documents',
                                    subtitle: 'Saved documents you can reuse in any analysis',
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StatCard(
                                          icon: Icons.shield_outlined,
                                          tone: AppTone.brand,
                                          count: stats.totalPolicies,
                                          label: 'Policies',
                                          onTap: () async {
                                            ref.invalidate(policiesProvider);
                                            await context.push('/policies');
                                            ref.invalidate(dashboardStatsProvider);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: _StatCard(
                                          icon: Icons.medication_outlined,
                                          tone: AppTone.verify,
                                          count: stats.totalPrescriptions,
                                          label: 'Prescriptions',
                                          onTap: () async {
                                            ref.invalidate(prescriptionProvider);
                                            await context.push('/prescriptions');
                                            ref.invalidate(dashboardStatsProvider);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.section + AppSpacing.xs),
                                  SectionHeader(
                                    title: 'Recent analyses',
                                    subtitle: stats.totalAnalysisReports > 0
                                        ? '${stats.totalAnalysisReports} '
                                              '${stats.totalAnalysisReports == 1 ? 'report' : 'reports'} in total'
                                        : null,
                                    trailing: TextButton(
                                      onPressed: () => context.go('/reports'),
                                      child: const Text('View all'),
                                    ),
                                  ),
                                  if (stats.recentAnalyses.isEmpty)
                                    AppCard(
                                      child: EmptyState(
                                        compact: true,
                                        icon: Icons.assignment_outlined,
                                        title: 'No analyses yet',
                                        message:
                                            'Start a new analysis to see whether your treatment is covered by your policy.',
                                        action: TextButton.icon(
                                          onPressed: () => context.push('/consent'),
                                          icon: const Icon(Icons.add_rounded, size: 18),
                                          label: const Text('Start new analysis'),
                                        ),
                                      ),
                                    )
                                  else
                                    ...stats.recentAnalyses.map(
                                      (report) => Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                        child: _RecentAnalysisTile(
                                          report: report,
                                          onTap: () async {
                                            await context.push('/summary/${report.id}');
                                            ref.invalidate(dashboardStatsProvider);
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                                child: LoadingState(message: 'Loading your overview…'),
                              ),
                              error: (err, stack) => AppCard(
                                child: ErrorState(
                                  compact: true,
                                  title: 'Couldn\'t load your overview',
                                  message: friendlyErrorMessage(err),
                                  onRetry: () => ref.invalidate(dashboardStatsProvider),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Draggable floating Google AdMob banner
          const FloatingBannerAd(),
        ],
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final authState = ref.watch(authProvider);
    final String? name = authState.when(
      data: (user) => (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'User',
      loading: () => null,
      error: (_, _) => 'User',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back,', style: context.text.bodyMedium?.copyWith(color: p.textTertiary)),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: name == null
              ? Container(
                  key: const ValueKey('name-loading'),
                  margin: const EdgeInsets.only(top: 6),
                  width: 160,
                  height: 22,
                  decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: AppRadius.smAll),
                )
              : Text(
                  name,
                  key: const ValueKey('name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.headlineSmall,
                ),
        ),
      ],
    );
  }
}

class _StartAnalysisCard extends StatelessWidget {
  final VoidCallback onStart;

  const _StartAnalysisCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const onNavy = Colors.white;
    final onNavyMuted = Colors.white.withAlpha(200);

    return Container(
      decoration: BoxDecoration(color: p.navy, borderRadius: AppRadius.xlAll),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -20,
            child: Icon(Icons.health_and_safety_outlined, size: 150, color: Colors.white.withAlpha(14)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: AppRadius.pillAll),
                  child: Text(
                    'COVERAGE CHECK',
                    style: context.text.labelSmall?.copyWith(color: onNavy, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Check claim eligibility', style: context.text.titleLarge?.copyWith(color: onNavy, fontSize: 20)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Upload your prescription and policy to see what is covered before you file a claim.',
                  style: context.text.bodyMedium?.copyWith(color: onNavyMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: const [
                    _HeroStep(number: 1, label: 'Prescription'),
                    _HeroStep(number: 2, label: 'Policy'),
                    _HeroStep(number: 3, label: 'Coverage result'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0B2545),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Start new analysis'),
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

class _HeroStep extends StatelessWidget {
  final int number;
  final String label;

  const _HeroStep({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(120)),
          ),
          child: Text(
            '$number',
            style: context.text.labelSmall?.copyWith(color: Colors.white, letterSpacing: 0, fontSize: 10.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: context.text.labelMedium?.copyWith(color: Colors.white.withAlpha(220))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final AppTone tone;
  final int count;
  final String label;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.tone,
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, tone: tone, size: 38),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: p.textTertiary, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('$count', style: context.text.headlineSmall?.copyWith(fontSize: 26)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
        ],
      ),
    );
  }
}

class _RecentAnalysisTile extends StatelessWidget {
  final AnalysisReport report;
  final VoidCallback onTap;

  const _RecentAnalysisTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final status = (report.overallStatus ?? '').trim().isEmpty ? 'Pending' : report.overallStatus!.trim();
    final style = coverageStatusStyle(status);
    final policy = report.displayPolicyName;
    final hasPolicy = policy.isNotEmpty && policy != 'Not Specified';
    final dateStr = report.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(report.createdAt!.toLocal())
        : '';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconTile(icon: style.icon, tone: style.tone, size: 42),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        report.displayReportNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    StatusBadge(label: status, tone: style.tone, dense: true),
                  ],
                ),
                if (hasPolicy) ...[
                  const SizedBox(height: 3),
                  Text(
                    policy,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: p.textTertiary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: p.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded, color: p.textTertiary, size: 22),
        ],
      ),
    );
  }
}
