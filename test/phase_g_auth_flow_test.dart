import 'package:claimsupport/core/config/app_config_provider.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/authentication/presentation/screens/login_screen.dart';
import 'package:claimsupport/features/authentication/presentation/screens/register_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('email login and account creation match verification states in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final requests = <RequestOptions>[];
      final client = ApiClient();
      final previous = client.dio;
      final dio = Dio();
      client.dio = dio;
      addTearDown(() {
        client.dio = previous;
        dio.close();
      });
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            if (request.path == '/auth/send-otp') {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {'otpLength': 6, 'resendAfterSeconds': 30, 'delivered': true},
                ),
              );
              return;
            }
            handler.reject(
              DioException.badResponse(
                requestOptions: request,
                statusCode: 400,
                response: Response(
                  requestOptions: request,
                  statusCode: 400,
                  data: {'detail': 'Invalid or expired OTP. Please request a new code if needed.'},
                ),
              ),
            );
          },
        ),
      );
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
          GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appConfigProvider.overrideWith((_) async => AppRuntimeConfig.defaults)],
          child: MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(brightness: brightness),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder button(String label) => find.widgetWithText(AppButton, label);
      void expectAuthArtwork() {
        final asset = 'assets/backgrounds/auth_bg_${brightness.name}.png';
        final finder = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == asset,
        );
        expect(tester.widget<Image>(finder).height, 300);
      }

      const email = 'example@example.com';
      expect(find.text('Log in'), findsOneWidget);
      expectAuthArtwork();
      final logo = tester.widget<Image>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == 'assets/logo.png',
        ),
      );
      expect((logo.image as AssetImage).assetName, 'assets/logo.png');
      expect(tester.getBottomLeft(button('Send code')).dy, greaterThan(770));

      await tester.enterText(find.byType(TextField), email);
      await tester.tap(button('Send code'));
      await tester.pumpAndSettle();
      expect(requests.single.data, containsPair('purpose', 'login'));
      expect(find.text('Check your email'), findsOneWidget);
      expectAuthArtwork();
      expect(find.text(email), findsOneWidget);
      expect(tester.widget<AppButton>(button('Verify')).onPressed, isNull);
      final code = find.byType(TextField);
      await tester.enterText(code, '482719');
      await tester.pumpAndSettle();
      expect(find.text('9'), findsOneWidget);
      await tester.tap(button('Verify'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/auth/login');
      expect(find.text("That code isn't right. Check it, or get a new one."), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/auth/send-otp');
      expect(tester.widget<AppButton>(button('Verify')).onPressed, isNull);

      await tester.tap(find.text('Change email'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, email);
      await tester.tap(find.text('New to Policy Pal? Create account', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsOneWidget);
      expectAuthArtwork();
      await tester.enterText(find.byType(TextField).first, 'Example Member');
      await tester.enterText(find.byType(TextField).last, email);
      await tester.tap(button('Send code'));
      await tester.pumpAndSettle();
      expect(requests.last.data, containsPair('purpose', 'register'));
      await tester.enterText(find.byType(TextField), '482719');
      await tester.pumpAndSettle();
      await tester.tap(button('Verify'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/auth/register');
      expect(requests.last.data, containsPair('name', 'Example Member'));
      expect(tester.takeException(), isNull);
    });
  }
}
