import 'package:intl/intl.dart';

import 'package:claimsupport/core/utils/activity_timestamp.dart';

/// A Coverage Analysis Reports list entry.
///
/// One group = one analysis. When several policies were analysed against the
/// same prescription they share a group; a classic single-policy analysis is a
/// group of one. Each policy inside keeps its own independent result.
class PolicyReportRow {
  final String policyId;
  final String policyName;
  final String policyNumber;
  final String insuranceCompany;
  final String policyStartDate;
  final String policyEndDate;
  final String status;
  final String overallStatus;
  final String outcome;
  final String decisionType;
  final double dominanceScore;
  final int processingTimeMs;
  final String reportId;
  final String reportLabel;
  final String errorMessage;
  final String failedAtStage;
  final List<dynamic> questions;
  final List<String> reasons;

  const PolicyReportRow({
    required this.policyId,
    required this.policyName,
    required this.policyNumber,
    required this.insuranceCompany,
    this.policyStartDate = '',
    this.policyEndDate = '',
    required this.status,
    required this.overallStatus,
    required this.outcome,
    required this.decisionType,
    required this.dominanceScore,
    required this.processingTimeMs,
    required this.reportId,
    required this.reportLabel,
    required this.errorMessage,
    this.failedAtStage = '',
    required this.questions,
    this.reasons = const [],
  });

  factory PolicyReportRow.fromJson(Map<String, dynamic> json) {
    return PolicyReportRow(
      policyId: json['policyId']?.toString() ?? '',
      policyName: policyProductName([json['policyName'], json['planName'], json['productName']]) ?? '',
      policyNumber: json['policyNumber']?.toString() ?? '',
      insuranceCompany: json['insuranceCompany']?.toString() ?? '',
      policyStartDate: json['policyStartDate']?.toString() ?? '',
      policyEndDate: json['policyEndDate']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      overallStatus: json['overallStatus']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? '',
      decisionType: json['decisionType']?.toString() ?? '',
      dominanceScore: (json['dominanceScore'] as num?)?.toDouble() ?? 0.0,
      processingTimeMs: (json['processingTimeMs'] as num?)?.toInt() ?? 0,
      reportId: json['reportId']?.toString() ?? '',
      reportLabel: json['reportLabel']?.toString() ?? '',
      errorMessage: json['errorMessage']?.toString() ?? '',
      failedAtStage: json['failedAtStage']?.toString().trim().toLowerCase() ?? '',
      questions: (json['questions'] as List?) ?? const [],
      reasons: [
        for (final reason in (json['reasons'] as List? ?? const []).whereType<String>())
          if (reason.trim().isNotEmpty) reason.trim(),
      ],
    );
  }

  bool get hasReport => reportId.isNotEmpty;
  bool get isWaitingForUser => status == 'waiting_for_user';
  bool get isFailed => status == 'failed' || status == 'invalid';
  bool get isRunning =>
      status == 'queued' || status == 'extracting' || status == 'analyzing' || status == 'reanalyzing';

  String? get productName => policyProductName([policyName]);

  String get displayName => productName ?? policyProductName([insuranceCompany]) ?? 'Policy';

  static String? policyProductName(Iterable<Object?> candidates) {
    const placeholders = {
      '',
      '-',
      'uploaded policy',
      'policy',
      'unknown',
      'n/a',
      'null',
      'none',
      'not specified',
    };
    for (final candidate in candidates.whereType<String>()) {
      final name = candidate.trim();
      if (!placeholders.contains(name.toLowerCase())) return name;
    }
    return null;
  }

  String get displayPeriod {
    final start = _formatDateStr(policyStartDate);
    final end = _formatDateStr(policyEndDate);
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start to $end';
    }
    if (start.isNotEmpty) return start;
    if (end.isNotEmpty) return end;
    return '';
  }

  static String _formatDateStr(String raw) {
    if (raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        return DateFormat('dd-MMM-yyyy').format(dt);
      }
    } catch (_) {}
    return raw;
  }

  /// Text for the per-policy status chip.
  String get statusLabel {
    if (isWaitingForUser) return 'Needs your input';
    if (status == 'failed') return 'Failed';
    if (status == 'invalid') return overallStatus.isNotEmpty ? overallStatus : 'Invalid policy';
    if (status == 'manual_review_required') return 'Manual review';
    if (isRunning) return 'Analyzing';
    return overallStatus.isNotEmpty ? overallStatus : 'Completed';
  }

  String get displayProcessingTime =>
      processingTimeMs > 0 ? '${(processingTimeMs / 1000).toStringAsFixed(1)}s' : '';

  Map<String, dynamic> toJson() => {
    'policyId': policyId,
    'policyName': policyName,
    'policyNumber': policyNumber,
    'insuranceCompany': insuranceCompany,
    'policyStartDate': policyStartDate,
    'policyEndDate': policyEndDate,
    'status': status,
    'overallStatus': overallStatus,
    'outcome': outcome,
    'decisionType': decisionType,
    'dominanceScore': dominanceScore,
    'processingTimeMs': processingTimeMs,
    'reportId': reportId,
    'reportLabel': reportLabel,
    'errorMessage': errorMessage,
    'failedAtStage': failedAtStage,
    'questions': questions,
    'reasons': reasons,
  };
}

class AnalysisReportGroup {
  final String groupId;
  final String groupType; // 'multi' | 'single'
  final bool isDurableJob;
  final String prescriptionId;
  final String status;
  final int policyCount;
  final int completedCount;
  final int totalProcessingTimeMs;
  final List<String> reportIds;
  final List<PolicyReportRow> policyReports;
  final Map<String, dynamic> prescription;
  final String displayName;
  final DateTime? createdAt;

  /// Multi-policy checks only: the policy the backend ranks best. Empty when
  /// no policy is covered or partially covered (backend display hint).
  final String bestPolicyId;

  const AnalysisReportGroup({
    this.displayName = '',
    this.bestPolicyId = '',
    this.isDurableJob = false,
    required this.groupId,
    required this.groupType,
    required this.prescriptionId,
    required this.status,
    required this.policyCount,
    required this.completedCount,
    required this.totalProcessingTimeMs,
    required this.reportIds,
    required this.policyReports,
    required this.prescription,
    required this.createdAt,
  });

  factory AnalysisReportGroup.fromJson(Map<String, dynamic> json) {
    return AnalysisReportGroup(
      groupId: json['groupId']?.toString() ?? '',
      groupType: json['groupType']?.toString() ?? 'single',
      isDurableJob: json['isDurableJob'] == true,
      prescriptionId: json['prescriptionId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      policyCount: (json['policyCount'] as num?)?.toInt() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      totalProcessingTimeMs: (json['totalProcessingTimeMs'] as num?)?.toInt() ?? 0,
      reportIds: ((json['reportIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      policyReports: ((json['policyReports'] as List?) ?? const [])
          .map((e) => PolicyReportRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      prescription: Map<String, dynamic>.from(
        (json['prescriptionJson'] as Map?) ?? (json['prescription'] as Map?) ?? const {},
      ),
      displayName: json['displayName']?.toString() ?? '',
      createdAt: parseActivityTimestamp(json['createdAt']),
      bestPolicyId:
          (json['comparisonSummary'] is Map ? json['comparisonSummary']['bestPolicyId'] : null)?.toString() ??
          '',
    );
  }

  bool get isMultiPolicy => groupType == 'multi' && policyCount > 1;

  String get diagnosis => prescription['diagnosis']?.toString() ?? '';
  String? localizedDiagnosis(String language) {
    final diagnoses = prescription['localizedDiagnoses'];
    final value = diagnoses is Map ? diagnoses[language] : null;
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
  String get patientName => prescription['patientName']?.toString() ?? '';
  String get visitDate => prescription['visitDate']?.toString() ?? '';

  String get displayVisitDate {
    if (visitDate.trim().isEmpty) return '';
    try {
      final dt = DateTime.tryParse(visitDate);
      if (dt != null) {
        return DateFormat('dd-MMM-yyyy').format(dt);
      }
    } catch (_) {}
    return visitDate;
  }

  /// Heading for the group card.
  String get title {
    if (diagnosis.trim().isNotEmpty) return diagnosis.trim();
    if (patientName.trim().isNotEmpty) return patientName.trim();
    if (policyReports.isNotEmpty) {
      final label = policyReports.first.reportLabel;
      if (label.isNotEmpty) return label;
    }
    return 'Coverage Analysis';
  }

  /// Overall status text shown on the group header.
  String get statusLabel {
    switch (status) {
      case 'partial':
        return 'Partially completed';
      case 'waiting_for_user':
        return 'Needs your input';
      case 'failed':
        return 'Failed';
      case 'queued':
      case 'extracting':
      case 'analyzing':
      case 'reanalyzing':
        return 'Analyzing';
      case 'manual_review_required':
        return 'Manual review';
      case 'completed':
        return 'Completed';
      default:
        return status.isEmpty ? 'Pending' : status;
    }
  }

  String get displayProcessingTime =>
      totalProcessingTimeMs > 0 ? '${(totalProcessingTimeMs / 1000).toStringAsFixed(1)}s' : '';

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'groupType': groupType,
    'isDurableJob': isDurableJob,
    'prescriptionId': prescriptionId,
    'status': status,
    'policyCount': policyCount,
    'completedCount': completedCount,
    'totalProcessingTimeMs': totalProcessingTimeMs,
    'reportIds': reportIds,
    'policyReports': [for (final row in policyReports) row.toJson()],
    'prescription': prescription,
    'displayName': displayName,
    'createdAt': createdAt?.toIso8601String(),
    'comparisonSummary': {'bestPolicyId': bestPolicyId},
  };
}
