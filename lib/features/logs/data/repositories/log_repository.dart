import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/logs/data/models/activity_log.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return LogRepository(apiClient: ApiClient());
});

class LogRepository {
  final ApiClient apiClient;

  LogRepository({required this.apiClient});

  Future<PaginatedActivityLogs> getLogs({int page = 1, int limit = 20}) async {
    try {
      final response = await apiClient.dio.get('/logs', queryParameters: {
        'page': page,
        'limit': limit,
      });
      return PaginatedActivityLogs.fromJson(response.data);
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? e.message ?? 'Unknown error',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(
        message: 'Failed to fetch logs: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }
}
