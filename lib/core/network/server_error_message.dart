import 'dart:io' show HttpException, SocketException;

import 'package:dio/dio.dart';

import '../config/env_config.dart';
import '../exceptions/app_exception.dart';
import '../localization/localization.dart';

Object? _underlyingError(Object? error) {
  while (error is AppException) {
    error = error.originalException;
  }

  return error;
}

String? serverErrorMessage(Object? error, {AppLocalizations? l10n}) {
  error = _underlyingError(error);
  final tamil = l10n?.localeName == 'ta' ? l10n : null;
  final connection = tamil?.sharedNetwork ?? _connectionMessage;
  if (error is SocketException) return connection;
  if (error is! DioException) return null;

  return switch (error.type) {
    DioExceptionType.connectionError => connection,
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => tamil?.sharedTimeout ?? 'Policy Pal’s server took too long to respond. Please try again.',
    DioExceptionType.unknown when error.error is SocketException || error.error is HttpException => connection,
    DioExceptionType.badResponse when (error.response?.statusCode ?? 0) >= 500 =>
      tamil?.sharedServerError ?? 'Policy Pal’s server is having trouble right now. Please try again in a moment.',
    _ => null,
  };
}

String get _connectionMessage => EnvConfig.isProd
    ? 'We couldn’t reach Policy Pal’s server. Check your internet connection and try again.'
    : 'We couldn’t reach Policy Pal on your computer. Make sure the server is running and this phone is on the same network, then try again.';


String localizedRequestError(Object? error, AppLocalizations l10n) {
  final serverMessage = serverErrorMessage(error, l10n: l10n);
  if (serverMessage != null) return serverMessage;
  final cause = _underlyingError(error);
  final response = cause is DioException ? cause.response : null;
  final data = response?.data;
  final code = data is Map ? data['errorCode'] : null;
  final params = data is Map ? data['params'] : null;
  return switch ((code, response?.statusCode)) {
    ('AUTHENTICATION_REQUIRED', _) || (_, 401) => l10n.sharedSessionInvalid,
    ('FORBIDDEN', _) || (_, 403) => l10n.sharedForbidden,
    ('NOT_FOUND', _) || (_, 404) => l10n.sharedNotFound,
    ('CONFLICT', _) || (_, 409) => l10n.sharedConflict,
    ('FILE_SIZE_EXCEEDED', _) when params is Map && params['maxSizeMb'] is int =>
      l10n.sharedFileLimit(params['maxSizeMb'] as int),
    ('FILE_SIZE_EXCEEDED', _) || (_, 413) => l10n.sharedFileTooLarge,
    ('UNSUPPORTED_FILE_FORMAT', _) || (_, 415) => l10n.sharedUnsupportedFile,
    ('TOO_MANY_REQUESTS', _) || (_, 429) => l10n.sharedTooManyRequests,
    ('INVALID_REQUEST', _) || (_, 400 || 422) => l10n.sharedInvalidRequest,
    ('INTERNAL_ERROR', _) => l10n.sharedServerError,
    _ => l10n.sharedLoadFailed,
  };
}
