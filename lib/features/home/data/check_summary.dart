import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';

import 'package:claimsupport/core/design/app_check_status.dart';

export 'package:claimsupport/core/design/app_check_status.dart';

enum CheckIssue { review, invalidPrescription }

/// UI data for a group returned by /analysis/grouped.
@immutable
class CheckSummary {
  const CheckSummary({
    required this.id,
    required this.treatment,
    required this.dateLabel,
    required this.meta,
    required this.statusLabel,
    required this.statusKind,
    required this.route,
    this.patientName = '',
    this.createdAt,
    this.group,
    this.policyCount = 0,
    this.bestPolicyName = '',
    this.issue,
  });

  final String id;
  final String treatment;
  final String dateLabel;
  final String patientName;
  final DateTime? createdAt;
  final AnalysisReportGroup? group;

  final String meta;
  final int policyCount;
  final String bestPolicyName;
  final CheckIssue? issue;
  final String statusLabel;
  final CheckStatusKind statusKind;

  /// Where tapping the card goes (existing details screens).
  final String route;

  String? get actionRoute {
    if (statusKind == CheckStatusKind.failed && issue == null) {
      final prescription = group?.prescriptionId ?? '';
      return Uri(
        path: '/check/new',
        queryParameters: prescription.isEmpty ? null : {'prescription': prescription},
      ).toString();
    }
    if (statusKind != CheckStatusKind.verification) return null;
    if (route.startsWith('/check/processing/')) return route;
    if (group?.status == 'waiting_for_user' || policyResults.any((row) => row.isWaitingForUser)) {
      return group?.isDurableJob == true
          ? '/check/processing/${Uri.encodeComponent(id)}'
          : Uri(path: '/analysis-multi', queryParameters: {'session': id}).toString();
    }
    return route;
  }

  static const _running = {
    'pending',
    'queued',
    'extracting',
    'analyzing',
    'reanalyzing',
    'running',
    'extracting_documents',
    'extracting_policy_metadata',
  };

  List<PolicyReportRow> get policyResults => group?.policyReports ?? const [];

  static (CheckStatusKind, String) resultForPolicy(PolicyReportRow policy, {String? overallStatus}) {
    if (policy.isRunning) return (CheckStatusKind.checking, 'Checking…');
    if (policy.isWaitingForUser) return (CheckStatusKind.other, 'Needs your input');
    if (policy.status == 'failed') {
      return (
        CheckStatusKind.failed,
        policy.failedAtStage.contains('extract') ? "Couldn't read" : 'Check failed',
      );
    }
    final raw = (overallStatus ?? policy.overallStatus).trim();
    if (policy.status == 'manual_review_required' ||
        raw.toLowerCase().replaceAll('_', ' ') == 'manual review required') {
      return (CheckStatusKind.verification, CheckStatusKind.verification.coverageLabel!);
    }
    if (policy.status == 'invalid') return (CheckStatusKind.other, raw.isEmpty ? 'Invalid policy' : raw);
    final kind = raw.isEmpty
        ? switch (policy.outcome) {
            'covered' => CheckStatusKind.covered,
            'partial' => CheckStatusKind.partial,
            'not_covered' => CheckStatusKind.notCovered,
            _ => CheckStatusKind.other,
          }
        : statusKindFor(raw);
    return (kind, kind.coverageLabel ?? (raw.isEmpty ? 'Result not available' : raw));
  }

  factory CheckSummary.fromGroup(AnalysisReportGroup g, {DateTime? now, String? accountName}) {
    final rows = g.policyReports;
    PolicyReportRow? best;
    int bestRank = 5;
    for (final row in rows) {
      final rank = _rank(row);
      if (rank < bestRank ||
          (rank == bestRank && g.bestPolicyId.isNotEmpty && row.policyId == g.bestPolicyId)) {
        best = row;
        bestRank = rank;
      }
    }
    final raw = _normalized(best?.overallStatus ?? '');
    final state = _normalized(g.status);
    final (kind, label, issue) = switch (state) {
      _ when _running.contains(g.status) || state == 'processing' => (
        CheckStatusKind.checking,
        'Checking\u2026',
        null,
      ),
      'waiting for user' || 'needs verification' => (CheckStatusKind.verification, 'Needs info', null),
      'failed' || 'check failed' => (CheckStatusKind.failed, "Couldn't check", null),
      'cancelled' || 'canceled' => (CheckStatusKind.other, 'Check cancelled', null),
      _
          when state == 'manual review required' ||
              raw == 'manual review required' ||
              best?.status == 'manual_review_required' =>
        (CheckStatusKind.other, 'Needs review', CheckIssue.review),
      _
          when state == 'invalid prescription' ||
              raw == 'invalid prescription' ||
              raw == 'invalid policy and prescription' ||
              (state == 'invalid' && raw.isEmpty) =>
        (CheckStatusKind.failed, 'Not a prescription', CheckIssue.invalidPrescription),
      _ when best == null => (CheckStatusKind.other, 'Result not available', null),
      _ => switch (resultForPolicy(best)) {
        (CheckStatusKind.verification, _) ||
        (_, 'Needs your input') => (CheckStatusKind.verification, 'Needs info', null),
        (CheckStatusKind.failed, _) => (CheckStatusKind.failed, "Couldn't check", null),
        (final kind, final label) => (kind, label, null),
      },
    };

    final fullName = cleanPatientName(g.patientName);
    final patient = fullName.isEmpty
        ? ''
        : fullName.toLowerCase() == cleanPatientName(accountName ?? '').toLowerCase()
        ? 'you'
        : fullName.split(' ').first;
    final count = g.policyCount > rows.length ? g.policyCount : rows.length;
    final date = g.createdAt?.toLocal();
    final id = Uri.encodeComponent(g.groupId);
    final displayName = g.displayName.trim().isEmpty
        ? g.prescription['displayName']?.toString() ?? ''
        : g.displayName;
    final title = _missing(displayName.trim()) ? g.diagnosis : displayName;

    return CheckSummary(
      id: g.groupId,
      treatment: cleanTreatment(title),
      patientName: patient,
      createdAt: date,
      group: g,
      dateLabel: date == null ? '' : displayDate(date, now ?? DateTime.now()),
      meta: checkMeta(patient, count),
      policyCount: count,
      bestPolicyName: best?.displayName ?? (count > 0 ? 'Policy' : ''),
      statusLabel: label,
      statusKind: kind,
      issue: issue,
      route: g.groupId.isEmpty ? '/reports' : '/checks/$id',
    );
  }

  static String checkMeta(String patient, int count) =>
      [if (patient.isNotEmpty) 'For $patient', if (count > 1) '$count policies compared'].join(' \u00b7 ');

  static String _normalized(String value) => value.trim().toLowerCase().replaceAll('_', ' ');

  static int _rank(PolicyReportRow row) => switch (resultForPolicy(row).$1) {
    CheckStatusKind.covered => 0,
    CheckStatusKind.partial => 1,
    CheckStatusKind.notCovered => 2,
    CheckStatusKind.verification when _normalized(row.overallStatus) == 'needs verification' => 3,
    _ => 4,
  };

  static String displayDate(DateTime date, DateTime now) {
    if (date.year == now.year && date.month == now.month && date.day == now.day)
      return DateFormat('h:mm a', 'en_US').format(date).toLowerCase();
    return DateFormat(date.year == now.year ? 'd MMM' : 'd MMM yyyy', 'en_US').format(date);
  }

  /// Maps the backend's status text to a dot colour. Unknown values are logged
  /// and shown neutral (handoff §5.9).
  static CheckStatusKind statusKindFor(String status) {
    switch (status.trim().toLowerCase().replaceAll('_', ' ')) {
      case 'covered':
      case 'fully covered':
        return CheckStatusKind.covered;
      case 'partially covered':
      case 'partially':
        return CheckStatusKind.partial;
      case 'not covered':
        return CheckStatusKind.notCovered;
      case 'needs verification':
        return CheckStatusKind.verification;
      case 'manual review required':
      case 'invalid policy':
      case 'invalid prescription':
      case 'invalid policy and prescription':
        return CheckStatusKind.other;
      default:
        debugPrint('[CheckSummary] Unrecognised coverage status: "$status"');
        return CheckStatusKind.other;
    }
  }

  static final _fileExtension = RegExp(r'\.(pdf|jpe?g|png|docx?|webp|heic|txt)$', caseSensitive: false);

  /// Diagnosis without codes, e.g. "Acute Appendicitis (ICD-10: K35.80)" →
  /// "Acute Appendicitis". Missing or file name → "Prescription".
  static String cleanTreatment(String diagnosis) {
    final cleaned = diagnosis
        .replaceAll(
          RegExp(r'[(\[]\s*(?:ICD[^)\]]*|[A-Z]\d{2}(?:\.[A-Z0-9]{1,4})?)\s*[)\]]', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _missing(cleaned) || _fileExtension.hasMatch(cleaned) ? 'Prescription' : cleaned;
  }

  /// "Mr. Rajesh Venkatraman" → "Rajesh Venkatraman".
  static String cleanPatientName(String name) {
    final cleaned = name
        .trim()
        .replaceFirst(RegExp(r'^(mr|mrs|ms|miss|master|dr|shri|smt|kum)\.?\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _missing(cleaned) ? '' : cleaned;
  }

  static bool _missing(String value) =>
      const {'', 'unknown', 'n/a', 'null', 'none', 'not specified'}.contains(value.toLowerCase());

  /// Relative dates for saved documents. Checks use [displayDate].
  static String relativeDate(DateTime date, DateTime now) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return switch (today.difference(day).inDays) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => DateFormat(date.year == now.year ? 'd MMM' : 'd MMM yyyy').format(date),
    };
  }
}
