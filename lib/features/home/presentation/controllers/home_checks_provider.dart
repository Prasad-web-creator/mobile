import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/checks/data/check_jobs.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/home/data/home_check_cache.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';

final restoredHomeCacheProvider = Provider<HomeCheckCache?>((ref) => null);

final homeCheckCacheProvider = Provider((ref) {
  final cache = ref.read(restoredHomeCacheProvider) ?? HomeCheckCache();
  ref.listen(authProvider.select((user) => user.value?.id), (previous, next) {
    if (previous != null && previous != next) cache.clear();
  });
  return cache;
});

final homeSnapshotProvider = Provider.autoDispose<HomeSnapshot?>((ref) {
  final user = ref.watch(authProvider).value;
  final cache = ref.watch(homeCheckCacheProvider);
  final checks = ref.watch(homeChecksProvider).value;
  final stats = ref.watch(dashboardStatsProvider).value;
  if (user == null || user.id.isEmpty) return cache.read(null);

  return cache.update(
    account: user.id,
    name: user.name,
    checks: checks,
    counts: stats == null ? null : (prescriptions: stats.totalPrescriptions, policies: stats.totalPolicies),
  );
});

/// Recent grouped reports plus durable jobs that may not yet have a report.
final homeChecksProvider = FutureProvider.autoDispose<List<CheckSummary>>((ref) async {
  final jobs = ref.watch(checkJobsProvider.future).catchError((_) => <CheckJob>[]);
  final user = ref.watch(authProvider.select((state) => state.value));
  final repository = ref.read(analysisReportRepositoryProvider);
  final page = await repository.getAnalysisReportGroups(page: 1, limit: 10);
  return recentHomeChecks(page.docs, await jobs, accountName: user?.name);
});

List<CheckSummary> recentHomeChecks(
  List<AnalysisReportGroup> groups,
  List<CheckJob> jobs, {
  DateTime? now,
  String? accountName,
}) {
  final today = now ?? DateTime.now();
  final byId = {
    for (final group in groups)
      if (group.groupId.isNotEmpty)
        group.groupId: CheckSummary.fromGroup(group, now: today, accountName: accountName),
  };
  for (final job in jobs) {
    if (!job.isRunning && !job.needsInput) continue;
    final grouped = byId[job.groupId];
    final date = grouped?.createdAt ?? job.createdAt;
    final count = grouped?.policyCount ?? job.policyCount;
    final patient = grouped?.patientName ?? '';
    byId[job.groupId] = CheckSummary(
      id: job.groupId,
      treatment:
          grouped?.treatment ??
          (job.treatment.isEmpty ? 'Coverage check' : CheckSummary.cleanTreatment(job.treatment)),
      dateLabel: date == null ? '' : CheckSummary.displayDate(date, today),
      createdAt: date,
      group: grouped?.group,
      meta: CheckSummary.checkMeta(patient, count),
      patientName: patient,
      policyCount: count,
      bestPolicyName: grouped?.bestPolicyName ?? (count > 0 ? 'Policy' : ''),
      statusLabel: job.needsInput ? 'Needs info' : 'Checking…',
      statusKind: job.needsInput ? CheckStatusKind.verification : CheckStatusKind.checking,
      route: job.processingPath,
    );
  }
  return byId.values.toList()..sort(
    (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
}
