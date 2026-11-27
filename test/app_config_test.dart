import 'package:claimsupport/core/config/app_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime limits accept configuration and enforce exact file bytes', () {
    final config = AppRuntimeConfig.fromJson({
      'maxFileSizeMb': 10,
      'maxPoliciesPerAnalysis': 1,
      'googleClientId': ' public-client-id ',
    });
    expect(config.acceptsFileSize(10 * 1024 * 1024), isTrue);
    expect(config.acceptsFileSize(10 * 1024 * 1024 + 1), isFalse);
    expect(config.policyLimitMessage, 'You can compare up to 1 policy at once.');
    expect(config.googleClientId, 'public-client-id');
  });

  test('older or malformed config uses the safe upload and analysis defaults', () {
    final config = AppRuntimeConfig.fromJson({
      'maxFileSizeMb': 20,
      'maxPoliciesPerAnalysis': 'five',
      'emailOtpEnabled': false,
    });
    expect(config.maxFileSizeMb, 5);
    expect(config.maxPolicies, 3);
    expect(config.emailOtpEnabled, isFalse);
  });
}
