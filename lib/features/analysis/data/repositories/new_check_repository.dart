import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/core/utils/device_app_info.dart';
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';
import 'package:claimsupport/features/analysis/presentation/controllers/analysis_controller.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/policies/data/repositories/policy_repository.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:claimsupport/features/prescriptions/data/repositories/prescription_repository.dart';

final newCheckRepositoryProvider = Provider<NewCheckRepository>(
  (ref) => NewCheckRepository(
    ApiClient().dio,
    ref.watch(analysisRepositoryProvider),
    ref.watch(prescriptionRepositoryProvider),
    ref.watch(policyRepositoryProvider),
  ),
);

final checkTreatmentsProvider = FutureProvider.autoDispose<List<Prescription>>(
  (ref) => ref.watch(newCheckRepositoryProvider).treatments(),
);

final checkPoliciesProvider = FutureProvider.autoDispose<List<Policy>>(
  (ref) => ref.watch(newCheckRepositoryProvider).policies(),
);

class DuplicateCheckPolicy implements Exception {
  const DuplicateCheckPolicy();
}

class UnreadableCheckDocument implements Exception {
  const UnreadableCheckDocument();
}

class WrongDocumentTypeException implements Exception {
  const WrongDocumentTypeException({
    required this.expectedType,
    required this.detectedType,
    required this.filename,
    required this.bytes,
  });

  final String expectedType;
  final String detectedType;
  final String filename;
  final List<int> bytes;
}

class NewCheckRepository {
  NewCheckRepository(this._dio, this._analysis, this._rx, this._policies);

  final Dio _dio;
  final AnalysisRepository _analysis;
  final PrescriptionRepository _rx;
  final PolicyRepository _policies;

  Future<List<Prescription>> treatments() => _allPages((page) => _rx.getPrescriptions(page: page, limit: 100));

  Future<List<Policy>> policies() => _allPages((page) => _policies.getPolicies(page: page, limit: 100));

  Future<List<T>> _allPages<T>(Future<PaginationResponse<T>> Function(int) load) async {
    final result = <T>[];
    var page = 1;
    while (true) {
      final response = await load(page);
      result.addAll(response.docs);
      if (!response.hasNextPage || response.docs.isEmpty) return result;
      page++;
    }
  }

  Future<String> createJob(String requestId) => _analysis.createJob(requestId);

  Future<Prescription> saveTypedPrescription(String text) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/prescriptions',
      data: {'isManual': true, 'extractedPrescriptionText': text, 'originalFileName': 'Manual Prescription'},
    );
    final saved = Prescription.fromJson(response.data!);
    if (saved.id.isEmpty) throw StateError('Could not save the prescription.');
    return saved;
  }

  Future<Map<String, dynamic>> readJob(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>('/analysis/jobs/$jobId');
    return response.data!;
  }

  Future<void> cancelJob(String jobId) => _analysis.stopJob(jobId);

  Future<void> submitAnswers(String jobId, String policyId, Map<String, dynamic> answers) async {
    await _analysis.updateJob(jobId, 'answer', policyId, CancelToken(), answers: answers);
  }

  Future<void> start(String jobId, String treatment, List<String> policies) async {
    try {
      await _analysis.startJob(jobId, treatment, policies, CancelToken());
    } catch (_) {
      // If the connection was interrupted after the server committed the
      // start, resume that job instead of submitting another analysis.
      try {
        if ((await readJob(jobId))['policyIds'] case final List selected when selected.isNotEmpty) {
          return;
        }
      } catch (_) {
        // Keep the original start error for the retry action.
      }
      rethrow;
    }
  }

  Future<Prescription?> findMatchingPrescriptionFile(String filename, int fileSize) async {
    final target = filename.trim().toLowerCase();
    if (target.isEmpty) return null;
    try {
      final saved = await treatments();
      for (final item in saved) {
        if (item.isManual) continue;
        final name = item.originalFileName?.trim().toLowerCase() ?? '';
        if (name != target) continue;
        if (item.fileSize == null || item.fileSize == 0 || item.fileSize == fileSize) {
          return item;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Policy?> findMatchingPolicyFile(String filename, int fileSize) async {
    final target = filename.trim().toLowerCase();
    if (target.isEmpty) return null;
    try {
      final saved = await policies();
      for (final item in saved) {
        final name = item.originalFileName?.trim().toLowerCase() ?? '';
        if (name != target) continue;
        if (item.fileSize == null || item.fileSize == 0 || item.fileSize == fileSize) {
          return item;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Policy?> findDuplicatePolicyByNumber(Policy candidate) async {
    final number = normalizePolicyNumber(candidate.policyNumber);
    if (number.isEmpty) return null;
    final saved = await policies();
    for (final item in saved) {
      if (item.id != candidate.id && normalizePolicyNumber(item.policyNumber) == number) {
        return item;
      }
    }
    return null;
  }

  Future<void> discardPolicy(String id) => _discard('/policies/$id');

  Future<void> discardPrescription(String id) => _discard('/prescriptions/$id');

  static bool _looksLikePolicyText(Prescription rx, String filename) {
    final text = (rx.extractedPrescriptionText ?? '').toLowerCase();
    const policyMarkers = [
      'policy schedule',
      'period of insurance',
      'sum insured',
      'waiting period',
      'policy number',
      'policyholder',
      'insured member',
      'pre-existing disease',
      'co-payment',
      'room rent',
      'terms and conditions',
      'uin:',
    ];
    final markerHits = policyMarkers.where(text.contains).length;
    final noDoctor = rx.doctorName.trim().isEmpty && rx.hospitalName.trim().isEmpty;
    if (markerHits >= 3 && noDoctor) return true;
    final lowerName = filename.toLowerCase();
    if (lowerName.contains('policy') && noDoctor && (rx.diagnosis == null || rx.diagnosis!.trim().isEmpty)) {
      return true;
    }
    return false;
  }

  static String? _detectedTypeFromValidity(dynamic validity) {
    if (validity is! Map) return null;
    final raw =
        (validity['detectedDocumentType'] ??
                validity['detectedDocumentTypeIfInvalid'] ??
                validity['documentType'] ??
                '')
            .toString()
            .toLowerCase();
    if (raw.contains('policy') || (validity['policyValid'] == true && validity['prescriptionValid'] == false)) {
      return 'policy';
    }
    if (raw.contains('prescription') || (validity['prescriptionValid'] == true && validity['policyValid'] == false)) {
      return 'prescription';
    }
    return null;
  }

  Future<Prescription> uploadTreatment({
    required String jobId,
    required String filename,
    required List<int> bytes,
  }) async {
    final record = await _uploadRecord(jobId, filename, bytes, 'prescription');
    try {
      await _analysis.preparePrescription(jobId, record, CancelToken());
      final job = await readJob(jobId);
      final detected = _detectedTypeFromValidity(job['documentValidity']);
      if (detected == 'policy') {
        await _discard('/prescriptions/$record');
        throw WrongDocumentTypeException(
          expectedType: 'prescription',
          detectedType: 'policy',
          filename: filename,
          bytes: bytes,
        );
      }
      final rx = await _rx.getPrescription(record);
      if (_looksLikePolicyText(rx, filename)) {
        await _discard('/prescriptions/$record');
        throw WrongDocumentTypeException(
          expectedType: 'prescription',
          detectedType: 'policy',
          filename: filename,
          bytes: bytes,
        );
      }
      return rx;
    } on WrongDocumentTypeException {
      rethrow;
    } catch (_) {
      // A polling timeout does not mean the queued worker stopped. Keep its
      // input while it owns the document so the server can finish the read.
      try {
        final job = await readJob(jobId);
        final detected = _detectedTypeFromValidity(job['documentValidity']);
        if (detected == 'policy') {
          await _discard('/prescriptions/$record');
          throw WrongDocumentTypeException(
            expectedType: 'prescription',
            detectedType: 'policy',
            filename: filename,
            bytes: bytes,
          );
        }
        if (job['status'] != 'cancelled' &&
            (job['prescriptionValid'] == false || const {'failed', 'expired'}.contains(job['status']))) {
          await _discard('/prescriptions/$record');
          throw const UnreadableCheckDocument();
        }
        if (job['prescriptionValid'] == true) {
          final rx = await _rx.getPrescription(record);
          if (_looksLikePolicyText(rx, filename)) {
            await _discard('/prescriptions/$record');
            throw WrongDocumentTypeException(
              expectedType: 'prescription',
              detectedType: 'policy',
              filename: filename,
              bytes: bytes,
            );
          }
          return rx;
        }
      } on WrongDocumentTypeException {
        rethrow;
      } on UnreadableCheckDocument {
        rethrow;
      } catch (_) {
        // Preserve the original error if the connection is unavailable.
      }
      rethrow;
    }
  }

  Future<Policy> uploadPolicy({
    required String jobId,
    required String filename,
    required List<int> bytes,
    bool throwOnDuplicate = false,
  }) async {
    final record = await _uploadRecord(jobId, filename, bytes, 'policy');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/policies/$record/extract-details',
        options: _jobOptions(jobId, timeout: const Duration(minutes: 4)),
      );
      final detected = _detectedTypeFromValidity(response.data?['documentValidity']);
      if (detected == 'prescription') {
        throw WrongDocumentTypeException(
          expectedType: 'policy',
          detectedType: 'prescription',
          filename: filename,
          bytes: bytes,
        );
      }
      if (response.data?['isPolicy'] != true) {
        if (filename.toLowerCase().contains('prescription') || filename.toLowerCase().contains('rx')) {
          throw WrongDocumentTypeException(
            expectedType: 'policy',
            detectedType: 'prescription',
            filename: filename,
            bytes: bytes,
          );
        }
        throw const UnreadableCheckDocument();
      }
      final policy = await _policies.getPolicy(record);
      if (throwOnDuplicate) {
        final duplicate = await findDuplicatePolicyByNumber(policy);
        if (duplicate != null) {
          throw const DuplicateCheckPolicy();
        }
      }
      return policy;
    } catch (_) {
      await _discard('/policies/$record');
      rethrow;
    }
  }

  static String normalizePolicyNumber(String? value) {
    final cleaned = value?.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '') ?? '';
    return const {'UNKNOWN', 'NA', 'NULL', 'NOTSPECIFIED', 'NONE'}.contains(cleaned) ? '' : cleaned;
  }

  Future<String> _uploadRecord(String jobId, String name, List<int> bytes, String type) async {
    final agreement = await DeviceAppInfo.buildAgreementData();
    final response = await _dio.post<Map<String, dynamic>>(
      '/upload',
      options: _jobOptions(jobId),
      data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: name), 'documentType': type}),
    );
    final fileId = response.data?['fileId']?.toString();
    if (fileId == null || fileId.isEmpty) {
      throw StateError('Upload returned no document.');
    }

    final isPolicy = type == 'policy';
    try {
      final record = await _dio.post<Map<String, dynamic>>(
        isPolicy ? '/policies' : '/prescriptions',
        options: _jobOptions(jobId),
        data: {
          if (isPolicy) ...{'insuranceCompany': '', 'policyNumber': '', 'policyName': 'Uploaded Policy'},
          'gridFsFileId': fileId,
          'originalFileName': name,
          'fileSize': bytes.length,
          'agreement': agreement,
        },
      );
      final recordId = (record.data?['_id'] ?? record.data?['id'])?.toString();
      if (recordId == null || recordId.isEmpty) {
        throw StateError('Could not save the document.');
      }
      return recordId;
    } catch (_) {
      await _discard('/upload/$fileId');
      rethrow;
    }
  }

  Options _jobOptions(String jobId, {Duration? timeout}) =>
      Options(headers: {'X-Analysis-Job-Id': jobId}, receiveTimeout: timeout);

  Future<void> _discard(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (error) {
      // Deletion after an interrupted connection may already have completed.
      if (error.response?.statusCode == 404) return;
    }
  }
}
