import 'package:flutter/foundation.dart';

enum Environment {
  dev,
  prod,
}

class EnvConfig {
  // Backend hosted on Render (service: claim-support-backend-python). Keep it in one
  // place: if the service is renamed or recreated its onrender.com URL changes.
  static const _prodApiBaseUrl = 'https://claim-support-backend-python.onrender.com/api';
  // Physical Android devices access the local backend via adb reverse tcp:8000 tcp:8000.
  static const _devApiBaseUrl = 'http://127.0.0.1:8000/api';

  static Environment _environment = kReleaseMode ? Environment.prod : Environment.dev;
  static String _apiBaseUrl = kReleaseMode
      ? const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _prodApiBaseUrl,
        )
      : const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _devApiBaseUrl,
        );

  static void initialize(Environment env) {
    _environment = env;
    const definedUrl = String.fromEnvironment('API_BASE_URL');

    switch (env) {
      case Environment.prod:
        _apiBaseUrl = definedUrl.isNotEmpty ? definedUrl : _prodApiBaseUrl;
        break;
      case Environment.dev:
        _apiBaseUrl = definedUrl.isNotEmpty ? definedUrl : _devApiBaseUrl;
        break;
    }
    debugPrint('[EnvConfig] Initialized in $env mode with Base URL: $_apiBaseUrl');
  }

  static String get apiBaseUrl => _apiBaseUrl;
  static bool get isProd => _environment == Environment.prod;
}
