import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';

const analysisDraftKey = SharedPrefs.analysisDraftKey;
const analysisResumeKey = SharedPrefs.analysisResumeKey;

Options analysisUploadOptions() {
  final id = SharedPrefs.instance.getString(analysisDraftKey);
  return Options(headers: {'X-Analysis-Job-Id': ?id});
}

class AnalysisRepository {
  final Dio _dio = ApiClient().dio;

  Future<String> createJob(String requestId) async {
    final config = await _dio.get('/app-config');
    final response = await _dio.post(
      '/analysis/jobs',
      data: {
        'accepted': true,
        'agreementVersion': config.data['analysisAgreementVersion'] ?? '1',
        'requestId': requestId,
      },
    );
    return response.data['id'] as String;
  }

  Future<Map<String, dynamic>> startJob(
    String jobId,
    String prescriptionPath,
    List<String> policyIds,
    CancelToken token,
  ) async {
    final response = await _dio.post(
      '/analysis/jobs/$jobId/start',
      data: {'prescriptionPath': prescriptionPath, 'policyIds': policyIds},
      cancelToken: token,
    );
    return jobSession(
      response.data as Map<String, dynamic>,
      policyIds: policyIds,
    );
  }

  Future<void> preparePrescription(
    String jobId,
    String prescriptionPath,
    CancelToken token,
  ) async {
    final path = '/analysis/jobs/$jobId';
    var response = await _dio.post(
      '$path/prescription',
      data: {'prescriptionPath': prescriptionPath},
      cancelToken: token,
    );
    final timer = Stopwatch()..start();
    while (true) {
      final job = response.data as Map<String, dynamic>;
      if (job['prescriptionValid'] == true) return;
      if (job['prescriptionValid'] == false ||
          const {'failed', 'cancelled', 'expired'}.contains(job['status'])) {
        throw AppException(
          message:
              job['error'] as String? ??
              'We could not read the prescription. Upload a clearer copy or enter the medical details manually.',
        );
      }
      if (timer.elapsed >= const Duration(minutes: 5)) {
        throw AppException(
          message:
              'The server is still reading the prescription. Tap Continue to check its progress again.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      response = await _dio.get(path, cancelToken: token);
    }
  }

  Future<Map<String, dynamic>> fetchJob(String jobId) async {
    final response = await _dio.get('/analysis/jobs/$jobId');
    return jobSession(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> cancelJob(String jobId) async {
    await stopJob(jobId);
    return jobSession({'id': jobId, 'status': 'cancelled'});
  }

  Future<void> stopJob(String jobId) async {
    final path = '/analysis/jobs/${Uri.encodeComponent(jobId)}';
    try {
      var response = await _dio.post<Map<String, dynamic>>('$path/cancel');
      final timer = Stopwatch()..start();
      while (response.data?['status'] == 'cancelling' && timer.elapsed < const Duration(seconds: 75)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        response = await _dio.get<Map<String, dynamic>>(path);
      }
      if (response.data?['status'] != 'cancelled') {
        throw AppException(message: 'The server has not confirmed that the analysis stopped.');
      }
    } on DioException catch (error) {
      // Stopped jobs are removed after their analysis records have been cleaned up.
      if (error.response?.statusCode != 404) rethrow;
    }
    final prefs = SharedPrefs.maybeInstance;
    if (prefs != null) {
      for (final key in [analysisDraftKey, analysisResumeKey]) {
        if (prefs.getString(key) == jobId) await prefs.remove(key);
      }
    }
  }

  Future<Map<String, dynamic>> updateJob(
    String jobId,
    String action,
    String policyId,
    CancelToken token, {
    Map<String, dynamic>? answers,
  }) async {
    final response = await _dio.post(
      '/analysis/jobs/$jobId/$action',
      data: {'policyId': policyId, 'answers': ?answers},
      cancelToken: token,
    );
    return jobSession(response.data as Map<String, dynamic>);
  }

  static Map<String, dynamic> jobSession(
    Map<String, dynamic> job, {
    List<String> policyIds = const [],
  }) {
    final result =
        (job['result'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final ids = (job['policyIds'] as List?)?.cast<String>() ?? policyIds;
    final status = job['status'] as String? ?? 'queued';
    final jobState = switch (status) {
      'created' ||
      'queued' ||
      'extracting_documents' ||
      'extracting_policy_metadata' ||
      'analyzing' ||
      'cancelling' ||
      'reanalyzing' => 'running',
      'cancelled' || 'expired' => 'failed',
      _ => status,
    };
    final label = switch (status) {
      'queued' => 'Waiting for the server to start analysis',
      'extracting_documents' => 'Reading the prescription and policies',
      'extracting_policy_metadata' => 'Reading policy details',
      _ => 'Preparing the analysis',
    };
    final activePolicyId = job['activePolicyId'];
    final rows =
        result['policyAnalyses'] as List? ??
        [
          for (final id in ids)
            {
              'policyId': id,
              'status': jobState == 'failed' ? 'failed' : 'queued',
              'stageLabel': label,
            },
        ];
    return {
      ...result,
      'sessionId': job['id'],
      'status': jobState == 'running' || jobState == 'failed'
          ? jobState
          : result['status'] ?? jobState,
      'errorMessage': switch (status) {
        'cancelled' => 'This analysis was cancelled.',
        'expired' => 'This analysis expired. Start a new analysis to try again.',
        _ => job['error'] ?? result['errorMessage'],
      },
      'policyCount': result['policyCount'] ?? ids.length,
      'canCancel': const {
        'queued', 'extracting_documents', 'extracting_policy_metadata',
        'analyzing', 'reanalyzing', 'waiting_for_user',
      }.contains(status),
      'policyAnalyses': [
        for (final row in rows)
          if (status == 'reanalyzing' && activePolicyId == row['policyId'])
            {
              ...(row as Map),
              'status': 'reanalyzing',
              'questions': [],
              'stageLabel': 'Checking updated details',
            }
          else
            row,
      ],
    };
  }

  Future<Map<String, dynamic>> startAnalysis(
    String prescriptionPath, {
    String? policyPath,
    String? policyId,
    required CancelToken cancelToken,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'prescriptionPath': prescriptionPath,
      };
      if (policyPath != null) requestData['policyPath'] = policyPath;
      if (policyId != null) requestData['policyId'] = policyId;

      final response = await _dio.post(
        '/analysis/start',
        data: requestData,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw AppException(
        message:
            'Analysis failed: Unexpected status code ${response.statusCode}',
      );
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(
          message: 'Analysis cancelled',
          originalException: e,
          stackTrace: st,
        );
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? 'Analysis failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(
        message: 'Failed to start analysis: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  /// Analyze one prescription against several policies in a single session.
  Future<Map<String, dynamic>> startMultiAnalysis(
    String prescriptionPath,
    List<String> policyIds, {
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '/analysis/start-multi',
        data: {'prescriptionPath': prescriptionPath, 'policyIds': policyIds},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw AppException(
        message:
            'Analysis failed: Unexpected status code ${response.statusCode}',
      );
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(
          message: 'Analysis cancelled',
          originalException: e,
          stackTrace: st,
        );
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message:
            e.response?.data?['detail'] ??
            e.response?.data?['message'] ??
            'Analysis failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(
        message: 'Failed to start analysis: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  /// Current state of a multi-policy session (safe to call repeatedly).
  Future<Map<String, dynamic>> fetchMultiAnalysis(
    String sessionId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/analysis/multi/$sessionId',
        cancelToken: cancelToken,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? 'Failed to load analysis',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    }
  }

  /// Answer clarification questions for ONE policy of a multi-policy session.
  Future<Map<String, dynamic>> submitPolicyAnswers(
    String sessionId,
    String policyId,
    Map<String, dynamic> answers, {
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '/analysis/multi/$sessionId/$policyId/answer',
        data: {'answers': answers},
        cancelToken: cancelToken,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(
          message: 'Submission cancelled',
          originalException: e,
          stackTrace: st,
        );
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? 'Submission failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    }
  }

  /// Retry a single failed policy without re-running the others.
  Future<Map<String, dynamic>> retryPolicy(
    String sessionId,
    String policyId, {
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '/analysis/multi/$sessionId/$policyId/retry',
        cancelToken: cancelToken,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? 'Retry failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<Map<String, dynamic>> submitAnswers(
    String sessionId,
    Map<String, dynamic> answers, {
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '/analysis/$sessionId/answer',
        data: {'answers': answers},
        options: Options(receiveTimeout: const Duration(minutes: 10)),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw AppException(
        message:
            'Submission failed: Unexpected status code ${response.statusCode}',
      );
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(
          message: 'Submission cancelled',
          originalException: e,
          stackTrace: st,
        );
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? 'Submission failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(
        message: 'Failed to submit answers: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }
}
