import 'package:claimsupport/core/routing/app_router.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:claimsupport/features/authentication/presentation/screens/splash_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android resolves the local session before starting the Flutter router', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));

    FlutterSecureStorage.setMockInitialValues({});
    expect(await SplashScreen.resolveDestination(), '/login');

    FlutterSecureStorage.setMockInitialValues({AppConstants.kAuthTokenKey: 'test-session'});
    await AppRouter.prepareStartup();
    expect(AppRouter.router.routeInformationProvider.value.uri.path, '/dashboard');
  });
}
