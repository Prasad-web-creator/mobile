import 'dart:async';

import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/checks/data/check_jobs.dart';
import 'package:claimsupport/features/checks/presentation/check_completion_monitor.dart';
import 'package:claimsupport/features/checks/presentation/check_notifications.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unreported durable jobs appear on Home, then give way to the real result', () {
    final now = DateTime(2026, 11, 26);
    final pending = CheckJob(id: 'new', status: 'queued', createdAt: now, groupId: 'group');
    final report = AnalysisReportGroup.fromJson({
      'groupId': 'group',
      'createdAt': '2026-11-26',
      'prescription': {'diagnosis': 'Treatment'},
      'status': 'completed',
      'policyReports': [
        {'overallStatus': 'Partially Covered'},
      ],
    });
    final waiting = recentHomeChecks([], [pending], now: now).single;
    expect(waiting.statusLabel, 'Checking…');
    expect(waiting.route, '/check/processing/new');

    final reading = recentHomeChecks([report], [pending], now: now).single;
    expect(reading.treatment, 'Treatment');
    expect(reading.statusKind, CheckStatusKind.checking);

    final completed = CheckJob(id: 'new', status: 'completed', createdAt: now, groupId: 'group');
    final result = recentHomeChecks([report], [completed], now: now).single;
    expect(result.statusKind, CheckStatusKind.partial);
    expect(result.route, '/checks/group');
  });

  test('leaving processing polls the durable job and emits a single completion alert', () async {
    final repository = _JobRepository();
    final notifications = _Notifications();
    final container = ProviderContainer.test(
      overrides: [
        authProvider.overrideWith(_Account.new),
        checkJobsRepositoryProvider.overrideWithValue(repository),
        checkNotificationsProvider.overrideWithValue(notifications),
      ],
    );
    await container.read(authProvider.future);
    final subscription = container.listen(checkCompletionMonitorProvider, (_, _) {});
    final monitor = container.read(checkCompletionMonitorProvider.notifier);
    monitor.track('job');
    monitor.setProcessingView('job', true);
    monitor.checkNow();
    expect(repository.requests, 0);
    monitor.setProcessingView('job', false);

    expect(await notifications.completed.future, (
      'job',
      'Your Policy Pal analysis for Acute Appendicitis with Appendicolith across 3 policies is complete. Tap to view.',
    ));
    await Future<void>.delayed(Duration.zero);
    monitor.checkNow();
    expect(repository.requests, 1);
    subscription.close();
  });

  test('completion uses the selected policy count when the job summary has none', () {
    final job = CheckJob.fromJson({
      'id': 'job',
      'status': 'completed',
      'policyIds': ['policy'],
    });
    expect(
      CheckNotifications.completionMessage(job, ''),
      'Your Policy Pal analysis for your prescription across 1 policy is complete. Tap to view.',
    );
  });
}

class _Account extends AuthNotifier {
  @override
  Future<User> build() async => User(id: 'fixture-account', name: 'Sample', email: 'fixture@example.com');
}

class _JobRepository extends CheckJobsRepository {
  int requests = 0;

  @override
  Future<CheckJob> find(String jobId) async {
    requests++;
    return CheckJob.fromJson({
      'id': jobId,
      'status': 'completed',
      'result': {
        'policyCount': 3,
        'prescription': {'diagnosis': 'Acute Appendicitis with Appendicolith (ICD-10: K35.80)'},
      },
    });
  }
}

class _Notifications extends CheckNotifications {
  final completed = Completer<(String, String)>();

  @override
  Future<bool?> requestPermission() async => true;

  @override
  Future<bool> show(CheckJob job, {String treatment = ''}) async {
    completed.complete((job.id, CheckNotifications.completionMessage(job, treatment)));
    return true;
  }
}
