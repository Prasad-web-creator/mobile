import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/documents/data/document_detail_fields.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';

typedef CheckDetailField = (String label, String value);

class CheckDocumentDetails {
  const CheckDocumentDetails({required this.fields, this.listField, this.fileId, this.mimeType});

  final List<CheckDetailField> fields;
  final (String label, List<String> values)? listField;
  final String? fileId;
  final String? mimeType;

  bool get hasData => fields.isNotEmpty || listField != null || fileId != null;
}

class CheckDetailsRepository {
  CheckDetailsRepository({Dio? client}) : _client = client ?? ApiClient().dio;

  final Dio _client;

  Future<Map<String, dynamic>?> loadReport(String reportId) => _getById('/analysis', reportId);

  Future<String?> loadPolicyProductName(String policyId) async {
    final record = await _getById('/policies', policyId);
    final extracted = _map(record?['extractedPolicyJson']);
    return PolicyReportRow.policyProductName([
      record?['policyName'],
      extracted['policyName'],
      extracted['planName'],
      extracted['productName'],
      record?['planName'],
      record?['productName'],
    ]);
  }

  Future<AnalysisReportGroup> loadGroup(String groupId) async {
    final id = Uri.encodeComponent(groupId);
    final grouped = await _get('/analysis/grouped/$id');
    if (grouped != null) return AnalysisReportGroup.fromJson(grouped);

    // Older API deployments have separate session and single-report lookups.
    final job = await _get('/analysis/jobs/$id');
    if (job != null) return _groupFromJob(groupId, job);
    final session = await _get('/analysis/multi/$id');
    if (session != null) return _groupFromSession(groupId, session);
    final report = await _get('/analysis/$id');
    if (report != null) return _groupFromReport(groupId, report);

    throw const CheckNotFoundException();
  }

  Future<CheckDocumentDetails> loadTreatment(AnalysisReportGroup group) async {
    final firstReport = group.policyReports.where((row) => row.hasReport).firstOrNull;
    final [record, snapshot] = await Future.wait([
      _getById('/prescriptions', group.prescriptionId),
      _getById('/analysis', firstReport?.reportId ?? ''),
    ]);
    final prescription = Prescription.fromJson({
      ...?record,
      'extractedPrescriptionJson': {
        ...group.prescription,
        ..._map(snapshot?['prescriptionJson']),
        ..._map(record?['extractedPrescriptionJson']),
      },
    });
    return CheckDocumentDetails(
      fields: prescriptionDetailFields(prescription),
      listField: prescription.items.isEmpty ? null : ('Items', prescription.items),
      fileId: _first([prescription.gridFsFileId]),
      mimeType: prescription.mimeType,
    );
  }

  Future<CheckDocumentDetails> loadPolicy(PolicyReportRow row) async {
    final [report, record] = await Future.wait([
      _getById('/analysis', row.reportId),
      _getById('/policies', row.policyId),
    ]);
    final policy = Policy.fromJson({
      ...?record,
      'extractedPolicyJson': {
        'insuranceCompany': row.insuranceCompany,
        'policyNumber': row.policyNumber,
        'policyEndDate': row.policyEndDate,
        ..._map(report?['policyJson']),
        ..._map(record?['extractedPolicyJson']),
      },
    });
    return CheckDocumentDetails(
      fields: policyDetailFields(policy),
      listField: policy.insuredMembers.isEmpty ? null : ('Members', policy.insuredMembers),
      fileId: _first([policy.gridFsFileId]),
      mimeType: policy.mimeType,
    );
  }

  Future<Uint8List> loadFile(String fileId) async {
    final response = await _client.get<List<int>>(
      '/upload/${Uri.encodeComponent(fileId)}',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<Map<String, dynamic>?> _getById(String path, String id) =>
      id.trim().isEmpty ? Future.value() : _get('$path/${Uri.encodeComponent(id)}');

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      return response.data;
    } on DioException catch (error) {
      if (const {404, 405}.contains(error.response?.statusCode)) return null;
      rethrow;
    }
  }

  static AnalysisReportGroup _groupFromJob(String id, Map<String, dynamic> job) {
    final result = _map(job['result']);
    final status = switch (job['status']) {
      'created' || 'queued' => 'queued',
      'extracting_documents' || 'extracting_policy_metadata' => 'extracting',
      'analyzing' || 'reanalyzing' || 'waiting_for_user' || 'cancelled' || 'failed' => job['status'],
      'expired' => 'failed',
      _ => result['status'] ?? job['status'],
    };
    return _groupFromSession(id, {
      ...result,
      'isDurableJob': true,
      'status': status,
      'createdAt': result['createdAt'] ?? job['createdAt'],
      'policyCount': result['policyCount'] ?? (job['policyIds'] as List?)?.length,
    });
  }

  static AnalysisReportGroup _groupFromSession(String id, Map<String, dynamic> session) {
    final rows = (session['policyAnalyses'] as List?) ?? const [];
    return AnalysisReportGroup.fromJson({
      ...session,
      'groupId': id,
      'groupType': 'multi',
      'policyReports': rows,
      'reportIds': [
        for (final row in rows)
          if (_map(row)['reportId'] case final String id when id.isNotEmpty) id,
      ],
    });
  }

  static AnalysisReportGroup _groupFromReport(String id, Map<String, dynamic> report) {
    final policy = _map(report['policyJson']);
    return AnalysisReportGroup.fromJson({
      ...report,
      'groupId': id,
      'groupType': 'single',
      'policyCount': 1,
      'prescription': _map(report['prescriptionJson']),
      'reportIds': [id],
      'policyReports': [
        {
          'reportId': id,
          'policyId': report['policyId'],
          'policyName': policy['policyName'],
          'insuranceCompany': policy['insuranceCompany'],
          'policyNumber': policy['policyNumber'],
          'policyEndDate': policy['policyEndDate'],
          'status': report['status'],
          'overallStatus': report['overallStatus'],
          'failedAtStage': report['failedAtStage'],
          'reasons': report['reasons'],
        },
      ],
    });
  }

  static Map<String, dynamic> _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : const {};

  static String? _first(List<Object?> candidates) {
    const missing = {'', '-', 'unknown', 'n/a', 'null', 'none', 'not specified'};
    for (final candidate in candidates) {
      final value = switch (candidate) {
        String() => candidate.trim(),
        num() => candidate.toString(),
        _ => '',
      };
      if (!missing.contains(value.toLowerCase())) return value;
    }
    return null;
  }
}

class CheckNotFoundException implements Exception {
  const CheckNotFoundException();
}
