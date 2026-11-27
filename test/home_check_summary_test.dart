import 'package:flutter_test/flutter_test.dart';

import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';

Map<String, dynamic> _row(
  String id,
  String name,
  String status, {
  String overall = '',
  String reportId = '',
}) => {
  'policyId': id,
  'policyName': name,
  'insuranceCompany': 'Star Health',
  'status': status,
  'overallStatus': overall,
  'reportId': reportId,
};

AnalysisReportGroup _group({
  String status = 'completed',
  String type = 'single',
  List<Map<String, dynamic>> rows = const [],
  Map<String, dynamic> rx = const {},
  String best = '',
  String createdAt = '2026-11-26T05:00:00Z',
}) => AnalysisReportGroup.fromJson({
  'groupId': 'g1',
  'groupType': type,
  'status': status,
  'policyCount': rows.length,
  'policyReports': rows,
  'prescription': rx,
  'createdAt': createdAt,
  if (best.isNotEmpty) 'comparisonSummary': {'bestPolicyId': best},
});

void main() {
  final now = DateTime(2026, 11, 26, 18);

  test('single policy: canonical status text, policy name, cleaned treatment and patient', () {
    final s = CheckSummary.fromGroup(
      _group(
        createdAt: DateTime(2026, 11, 26, 7, 45).toUtc().toIso8601String(),
        rows: [_row('p1', 'Prakriti Family Health', 'completed', overall: 'Covered', reportId: 'r1')],
        rx: {
          'diagnosis': 'Acute Appendicitis with Appendicolith  (ICD-10: K35.80)',
          'patientName': 'Mr. Rajesh Venkatraman',
        },
      ),
      now: now,
    );
    expect(s.treatment, 'Acute Appendicitis with Appendicolith');
    expect(s.meta, 'For Rajesh');
    expect(s.statusLabel, 'Fully covered');
    expect(s.statusKind, CheckStatusKind.covered);
    expect(s.dateLabel, '7:45 am');
    expect(s.route, '/checks/g1');
  });

  test('past checks this year show the local day and month', () {
    final savedAt = DateTime(2026, 11, 26, 22, 55);
    final utcFromServer = savedAt.toUtc().toIso8601String().replaceFirst('Z', '');
    final summary = CheckSummary.fromGroup(_group(createdAt: utcFromServer), now: DateTime(2026, 11, 27));
    expect(summary.dateLabel, '26 Nov');
  });

  test('multi policy uses the best policy for status, meta and route', () {
    final s = CheckSummary.fromGroup(
      _group(
        type: 'multi',
        best: 'p2',
        rows: [
          _row('p1', 'Navyug', 'completed', overall: 'Not Covered', reportId: 'r1'),
          _row('p2', 'Prakriti', 'completed', overall: 'Partially Covered', reportId: 'r2'),
        ],
      ),
      now: now,
    );
    expect(s.statusLabel, 'Partially covered');
    expect(s.statusKind, CheckStatusKind.partial);
    expect(s.meta, '2 policies compared');
    expect(s.bestPolicyName, 'Prakriti');
    expect(s.policyCount, 2);
    expect(s.route, '/checks/g1');
  });

  test('multi policy without a best policy hint keeps the first tied result', () {
    final s = CheckSummary.fromGroup(
      _group(
        type: 'multi',
        rows: [
          _row('p1', 'A', 'completed', overall: 'Not Covered'),
          _row('p2', 'B', 'completed', overall: 'Not Covered'),
        ],
      ),
      now: now,
    );
    expect(s.meta, '2 policies compared');
    expect(s.bestPolicyName, 'A');
    expect(s.statusLabel, 'Not covered');
    expect(s.statusKind, CheckStatusKind.notCovered);
  });

  test('manual review has its own check state', () {
    final s = CheckSummary.fromGroup(
      _group(rows: [_row('p1', 'A', 'manual_review_required', overall: 'Manual Review Required')]),
      now: now,
    );
    expect(s.statusLabel, 'Needs review');
    expect(s.issue, CheckIssue.review);
    expect(s.statusKind, CheckStatusKind.other);
  });

  test('processing, waiting and failed checks', () {
    expect(
      CheckSummary.fromGroup(
        _group(status: 'analyzing', rows: [_row('p1', 'A', 'analyzing')]),
        now: now,
      ).statusKind,
      CheckStatusKind.checking,
    );
    expect(
      CheckSummary.fromGroup(
        _group(status: 'waiting_for_user', rows: [_row('p1', 'A', 'waiting_for_user')]),
        now: now,
      ).statusLabel,
      'Needs info',
    );
    final failed = CheckSummary.fromGroup(
      _group(status: 'failed', rows: [_row('p1', 'A', 'failed')]),
      now: now,
    );
    expect(failed.statusLabel, "Couldn't check");
    expect(failed.route, '/checks/g1');
  });

  test('missing treatment, patient and placeholder policy names', () {
    final s = CheckSummary.fromGroup(
      _group(
        rows: [_row('p1', 'Uploaded Policy', 'completed', overall: 'Covered')],
        rx: {'patientName': ''},
      ),
      now: now,
    );
    expect(s.treatment, 'Prescription');
    expect(s.meta, isEmpty);
    expect(s.bestPolicyName, 'Star Health');
  });

  test('dates: today time / d MMM / d MMM yyyy', () {
    expect(CheckSummary.displayDate(DateTime(2026, 11, 26, 1), now), '1:00 am');
    expect(CheckSummary.displayDate(DateTime(2026, 11, 25, 23), now), '25 Nov');
    expect(CheckSummary.displayDate(DateTime(2026, 10, 12), now), '12 Oct');
    expect(CheckSummary.displayDate(DateTime(2025, 10, 12), now), '12 Oct 2025');
  });
}
