import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment {
  dev,
  prod,
}

class EnvConfig {
  // Backend hosted on Render (service: claim-support-backend-python). Keep it in one
  // place: if the service is renamed or recreated its onrender.com URL changes.
  static const _prodApiBaseUrl = 'https://claim-support-backend-python.onrender.com/api';
  // Dev machine's Wi-Fi IPv4 (run `ipconfig`); changes when the router assigns a new address.
  static const _devApiBaseUrl = 'http://192.168.0.113:8000/api';

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
    String? envFileUrl;
    try {
      envFileUrl = dotenv.env['API_BASE_URL'];
    } catch (_) {}

    switch (env) {
      case Environment.prod:
        _apiBaseUrl = const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _prodApiBaseUrl,
        );
        break;
      case Environment.dev:
        _apiBaseUrl = (envFileUrl != null && envFileUrl.isNotEmpty)
            ? envFileUrl
            : const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: _devApiBaseUrl,
              );
        break;
    }
    debugPrint('[EnvConfig] Initialized in $env mode with Base URL: $_apiBaseUrl');
  }

  static String get apiBaseUrl => _apiBaseUrl;
  static bool get isProd => _environment == Environment.prod;
}
