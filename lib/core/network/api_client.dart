import 'dart:io' show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';
import 'server_error_message.dart';
import '../config/env_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio dio;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: EnvConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: EnvConfig.isProd ? 12 : 3),
      sendTimeout: const Duration(seconds: 120),
      // Allow a hosted cold start. Document analysis itself runs in a background job.
      receiveTimeout: Duration(seconds: EnvConfig.isProd ? 80 : 20),
    ));

    // The server closes idle keep-alive connections after 5 s, while Dart keeps
    // them for 15 s by default. Reusing one the server already closed fails with
    // "Connection closed before full header was received". Drop idle
    // connections sooner than the server does so a closed one is never reused.
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..idleTimeout = const Duration(seconds: 3),
    );

    dio.interceptors.add(AuthInterceptor());
    dio.interceptors.add(RetryInterceptor(dio: dio, retryNetworkErrors: EnvConfig.isProd));
    
    
    dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) {
        String friendlyMessage = 'An unexpected error occurred. Please try again.';
        
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
          case DioExceptionType.connectionError:
          case DioExceptionType.unknown:
            friendlyMessage = serverErrorMessage(e) ?? friendlyMessage;
            break;
          case DioExceptionType.badCertificate:
            friendlyMessage = 'Secure connection failed. Please ensure your network is secure.';
            break;
          case DioExceptionType.badResponse:
            final statusCode = e.response?.statusCode;
            if (statusCode == 401) {
              friendlyMessage = 'Authentication failed. Please log in again.';
            } else if (statusCode != null && statusCode >= 500) {
              friendlyMessage = serverErrorMessage(e)!;
            } else {
              final body = e.response?.data;
              final message = body is Map ? body['message'] ?? body['detail'] : null;
              if (message is String) friendlyMessage = message;
            }
            break;
          default:
            break;
        }

        // Clone the exception to override the message for UI consumption
        final customException = e.copyWith(message: friendlyMessage);
        
        return handler.next(customException);
      },
    ));
  }
}

