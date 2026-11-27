import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/network/api_client.dart';

final appConfigProvider = FutureProvider.autoDispose<AppRuntimeConfig>((ref) async {
  final response = await ApiClient().dio.get('/app-config');
  return AppRuntimeConfig.fromJson(response.data is Map ? response.data as Map : const {});
});

final supportEmailProvider = FutureProvider.autoDispose<String?>((ref) async {
  return (await ref.watch(appConfigProvider.future)).supportEmail;
});

class AppRuntimeConfig {
  static const defaults = AppRuntimeConfig();
  static const _bytesPerMb = 1024 * 1024;

  final int maxFileSizeMb;
  final int maxPolicies;
  final String? supportEmail;
  final String? googleClientId;
  final bool emailOtpEnabled;

  const AppRuntimeConfig({
    this.maxFileSizeMb = 5,
    this.maxPolicies = 3,
    this.supportEmail,
    this.googleClientId,
    this.emailOtpEnabled = true,
  });

  factory AppRuntimeConfig.fromJson(Map data) {
    String? nonEmptyString(Object? value) {
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    int boundedInt(Object? value, int max, int fallback) {
      return value is int && value >= 1 && value <= max ? value : fallback;
    }

    return AppRuntimeConfig(
      maxFileSizeMb: boundedInt(data['maxFileSizeMb'], 10, defaults.maxFileSizeMb),
      maxPolicies: boundedInt(data['maxPoliciesPerAnalysis'], 5, defaults.maxPolicies),
      supportEmail: nonEmptyString(data['supportEmail']),
      googleClientId: nonEmptyString(data['googleClientId']),
      emailOtpEnabled: data['emailOtpEnabled'] != false,
    );
  }

  bool acceptsFileSize(int bytes) => bytes <= maxFileSizeMb * _bytesPerMb;

  String get uploadLimitMessage => 'Each file must be $maxFileSizeMb MB or smaller.';
  String get policyLimitMessage {
    final noun = maxPolicies == 1 ? 'policy' : 'policies';
    return 'You can compare up to $maxPolicies $noun at once.';
  }
}
