import 'dart:io' show HttpException, SocketException;

import 'package:dio/dio.dart';

import '../config/env_config.dart';
import '../exceptions/app_exception.dart';

String? serverErrorMessage(Object? error) {
  while (error is AppException) {
    error = error.originalException;
  }

  if (error is SocketException) return _connectionMessage;
  if (error is! DioException) return null;

  return switch (error.type) {
    DioExceptionType.connectionError => _connectionMessage,
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'Policy Pal’s server took too long to respond. Please try again.',
    DioExceptionType.unknown when error.error is SocketException || error.error is HttpException => _connectionMessage,
    DioExceptionType.badResponse when (error.response?.statusCode ?? 0) >= 500 =>
      'Policy Pal’s server is having trouble right now. Please try again in a moment.',
    _ => null,
  };
}

String get _connectionMessage => EnvConfig.isProd
    ? 'We couldn’t reach Policy Pal’s server. Check your internet connection and try again.'
    : 'We couldn’t reach Policy Pal on your computer. Make sure the server is running and this phone is on the same network, then try again.';
