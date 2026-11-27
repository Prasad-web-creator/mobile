import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Dio dio;
  final bool retryNetworkErrors;

  RetryInterceptor({
    this.maxRetries = 3,
    this.retryNetworkErrors = true,
    required this.dio,
  });

  /// An idle connection can close before the response arrives.
  bool _isStaleConnection(DioException err) {
    if (err.type != DioExceptionType.connectionError &&
        err.type != DioExceptionType.unknown) {
      return false;
    }
    final text = '${err.error ?? ''} ${err.message ?? ''}';
    return text.contains('Connection closed before full header was received');
  }

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.method != 'GET' &&
        err.requestOptions.method != 'HEAD') {
      return false;
    }
    if (_isStaleConnection(err))
      return (err.requestOptions.extra['retryCount'] ?? 0) < 1;
    if (!retryNetworkErrors) return false;

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    final statusCode = err.response?.statusCode;
    if (statusCode != null) {
      return statusCode == 408 || // Request Timeout
          statusCode == 429 || // Too Many Requests
          statusCode == 502 || // Bad Gateway
          statusCode == 503 || // Service Unavailable
          statusCode == 504; // Gateway Timeout
    }

    return false;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    int extraRetries = err.requestOptions.extra['retryCount'] ?? 0;

    if (_shouldRetry(err) && extraRetries < maxRetries) {
      extraRetries++;

      // Exponential backoff
      int delayMs =
          (pow(2, extraRetries) * 500).toInt() + Random().nextInt(500);
      debugPrint(
        '[RetryInterceptor] Request failed with ${err.response?.statusCode ?? err.type}. Retrying ($extraRetries/$maxRetries) in $delayMs ms...',
      );

      await Future.delayed(Duration(milliseconds: delayMs));

      try {
        err.requestOptions.extra['retryCount'] = extraRetries;

        final response = await dio.fetch<dynamic>(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        if (e is DioException) {
          return super.onError(e, handler);
        }
      }
    }

    return super.onError(err, handler);
  }
}
