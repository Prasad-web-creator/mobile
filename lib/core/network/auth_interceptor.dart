import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/core/routing/app_router.dart';

/// Outcome of a token refresh attempt.
enum _RefreshResult {
  /// New tokens saved.
  refreshed,

  /// The server rejected the refresh token (401/403) or there is none: the session is really over.
  rejected,

  /// Network error, timeout or server error: the session may still be valid, so keep it.
  unavailable,
}

class AuthInterceptor extends Interceptor {
  // Global lock for token refresh to prevent race conditions
  static Future<_RefreshResult>? _refreshFuture;
  
  // Flag to prevent duplicate session expired dialogs
  static bool _sessionExpiredShown = false;

  // Flag to indicate intentional manual logout
  static bool isManualLogout = false;

  /// Resets the session expired flag. Should be called after successful login.
  static void resetSessionExpiredFlag() {
    _sessionExpiredShown = false;
    isManualLogout = false;
  }

  /// Parses the JWT token to extract the payload map.
  Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      // Pad with '=' to make it a valid base64 string
      String normalized = base64Url.normalize(payload);
      String resp = utf8.decode(base64Url.decode(normalized));
      return json.decode(resp);
    } catch (e) {
      return null;
    }
  }

  /// Checks if the token is expiring in less than 5 minutes.
  bool _isTokenExpiringSoon(String token) {
    final payload = _parseJwt(token);
    // If we can't parse it or it lacks exp, assume it needs refresh
    if (payload == null || !payload.containsKey('exp')) {
      return true; 
    }

    final exp = payload['exp'] as int;
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    final now = DateTime.now().toUtc();

    // Check if expiring within 300 seconds (5 minutes)
    return expiryDate.difference(now).inSeconds < 300;
  }

  /// Clears session and shows a non-dismissible dialog before redirecting to login.
  Future<void> _logoutAndRedirectToLogin() async {
    // If it's an intentional manual logout, do not show the dialog and do not redirect 
    // (the profile screen will handle redirection).
    if (isManualLogout) return;

    // If a dialog was already shown, don't show another one.
    if (_sessionExpiredShown) return;
    _sessionExpiredShown = true;

    await AuthStorage.clearTokens();

    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Session Expired'),
          content: const Text('Your login session has expired. Please sign in again to continue.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    
    // Clear routes and force navigate to login
    AppRouter.router.go('/login');
  }

  /// Performs the actual refresh call to the backend.
  /// Only an explicit 401/403 from the server ends the session; being offline,
  /// a backend restart or a slow cold start must not log the user out.
  Future<_RefreshResult> _performRefresh(String baseUrl, String refreshToken) async {
    try {
      final freshDio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ));
      final response = await freshDio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      final newToken = response.data is Map ? response.data['token'] : null;
      final newRefreshToken = response.data is Map ? response.data['refreshToken'] : null;
      if (newToken == null) return _RefreshResult.unavailable;

      await AuthStorage.saveToken(newToken);
      if (newRefreshToken != null) {
        await AuthStorage.saveRefreshToken(newRefreshToken);
      }
      return _RefreshResult.refreshed;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) return _RefreshResult.rejected;
      debugPrint('[AuthInterceptor] Token refresh unavailable (${e.type}, status $status); keeping session.');
      return _RefreshResult.unavailable;
    } catch (e) {
      debugPrint('[AuthInterceptor] Token refresh error: $e; keeping session.');
      return _RefreshResult.unavailable;
    }
  }

  /// Orchestrates the refresh logic ensuring only one network call happens at a time.
  Future<_RefreshResult> _refreshTokens(String baseUrl) async {
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null) return _RefreshResult.rejected;

    // Wait for the ongoing refresh to finish if one is already in progress
    if (_refreshFuture != null) {
      return await _refreshFuture!;
    }

    // Start a new refresh process
    try {
      _refreshFuture = _performRefresh(baseUrl, refreshToken);
      return await _refreshFuture!;
    } finally {
      // Always clear the lock so subsequent valid refreshes can happen
      _refreshFuture = null;
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      String? token = await AuthStorage.getToken();

      if (token != null) {
        // Proactively check if the token is about to expire
        if (_isTokenExpiringSoon(token)) {
          final result = await _refreshTokens(options.baseUrl);
          if (result == _RefreshResult.refreshed) {
            token = await AuthStorage.getToken(); // Fetch the newly saved token
          } else if (result == _RefreshResult.rejected) {
            // Refresh failed proactively. Abort request and logout.
            await _logoutAndRedirectToLogin();
            return handler.reject(DioException(
              requestOptions: options,
              error: 'Session expired. Please log in again.',
              type: DioExceptionType.cancel,
            ));
          }
        }
        // _RefreshResult.unavailable: send with the current token; the request
        // fails or succeeds on its own and the session is kept.
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // If token retrieval fails, proceed without it (might be a public route)
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Safety net: if a 401 still happens (e.g. backend clock mismatch or revoked token)
    if (err.response?.statusCode == 401) {
      try {
        final result = await _refreshTokens(err.requestOptions.baseUrl);

        if (result == _RefreshResult.refreshed) {
          final newToken = await AuthStorage.getToken();

          // Retry the original request with the new token
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final opts = Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
          );

          // Create a fresh Dio instance to avoid interceptor loop for the retry
          final freshDio = Dio(BaseOptions(
            baseUrl: err.requestOptions.baseUrl,
          ));

          final retryResponse = await freshDio.request(
            err.requestOptions.path,
            options: opts,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
          );

          return handler.resolve(retryResponse);
        } else if (result == _RefreshResult.rejected) {
          // The server rejected the refresh token: the session is really over.
          await _logoutAndRedirectToLogin();
        }
        // _RefreshResult.unavailable: keep the session and pass the error on.
      } catch (e) {
        // e.g. the retried request itself failed: report it, but keep the session.
        debugPrint('[AuthInterceptor] Retry after refresh failed: $e');
      }
    }

    handler.next(err);
  }
}
