import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

class AnalysisReportRepository {
  final Dio _dio = ApiClient().dio;

  Future<PaginationResponse<AnalysisReportGroup>> getAnalysisReportGroups({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get('/analysis/grouped', queryParameters: {
        'page': page,
        'limit': limit,
      });
      return PaginationResponse.fromJson(
        response.data,
        (json) => AnalysisReportGroup.fromJson(json),
      );
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? e.response?.data?['message'] ?? e.message ?? 'Unknown error',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(
        message: 'Failed to fetch analysis reports: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  /// Delete a whole analysis group (every report it contains).
  Future<void> deleteAnalysisGroup(String groupId) async {
    try {
      await _dio.delete('/analysis/grouped/$groupId');
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? e.message ?? 'Unknown error',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<int> deleteBatchAnalysisGroups(List<String> ids) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/analysis/grouped/batch-delete', data: {'ids': ids});
      return (response.data!['deletedCount'] as num).toInt();
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? e.message ?? 'Unknown error',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    }
  }
}
