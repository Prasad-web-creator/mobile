import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/utils/activity_timestamp.dart';

final checkJobsRepositoryProvider = Provider((ref) => CheckJobsRepository());

final checkJobsProvider = FutureProvider.autoDispose<List<CheckJob>>((ref) {
  return ref.watch(checkJobsRepositoryProvider).recent();
});

class CheckJobsRepository {
  CheckJobsRepository({Dio? client}) : _client = client;

  final Dio? _client;
  Dio get _dio => _client ?? ApiClient().dio;

  Future<List<CheckJob>> recent() async {
    final response = await _dio.get<Map<String, dynamic>>('/analysis/jobs');
    final jobs = response.data?['jobs'];
    return [
      if (jobs is List)
        for (final record in jobs.whereType<Map<String, dynamic>>())
          if (record['id'] is String && (record['id'] as String).isNotEmpty) CheckJob.fromJson(record),
    ];
  }

  Future<CheckJob> find(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>('/analysis/jobs/${Uri.encodeComponent(jobId)}');
    return CheckJob.fromJson(response.data!);
  }

  Future<String> treatmentFor(CheckJob job) async {
    if (job.treatment.isNotEmpty) return job.treatment;
    try {
      final response = await _dio.get<Map<String, dynamic>>('/analysis/grouped/${Uri.encodeComponent(job.groupId)}');
      return CheckJob._diagnosis(response.data);
    } on DioException {
      return '';
    }
  }
}

class CheckJob {
  const CheckJob({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.groupId,
    this.policyCount = 0,
    this.treatment = '',
  });

  factory CheckJob.fromJson(Map<String, dynamic> record) {
    final result = record['result'];
    final id = record['id'] as String;
    final groupId = result is Map ? result['sessionId'] : null;
    final policies = record['policyIds'];
    final count = result is Map ? result['policyCount'] : null;
    return CheckJob(
      id: id,
      status: record['status']?.toString() ?? '',
      createdAt: parseActivityTimestamp(record['createdAt'])?.toLocal(),
      groupId: groupId is String && groupId.isNotEmpty ? groupId : id,
      policyCount: count is int && count > 0 ? count : (policies is List ? policies.length : 0),
      treatment: _diagnosis(result),
    );
  }

  final String id;
  final String status;
  final DateTime? createdAt;
  final String groupId;
  final int policyCount;
  final String treatment;

  static String _diagnosis(Object? result) {
    final prescription = result is Map ? result['prescription'] : null;
    final diagnosis = prescription is Map ? prescription['diagnosis'] : null;
    return diagnosis is String ? diagnosis.trim() : '';
  }

  bool get isRunning => const {
    'queued',
    'extracting_documents',
    'extracting_policy_metadata',
    'analyzing',
    'reanalyzing',
    'running',
  }.contains(status);
  bool get needsInput => status == 'waiting_for_user';
  bool get hasResult => const {'completed', 'partial', 'manual_review_required'}.contains(status);
  bool get isTerminal => hasResult || const {'failed', 'cancelled', 'expired'}.contains(status);

  String get processingPath => '/check/processing/${Uri.encodeComponent(id)}';
  String get resultPath => '/checks/${Uri.encodeComponent(groupId)}';
}
