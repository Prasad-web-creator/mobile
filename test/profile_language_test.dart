import 'dart:async';

import 'package:claimsupport/core/design/widgets/app_design_surface.dart';
import 'package:claimsupport/core/localization/locale_provider.dart';
import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPrefs.getAsync();
    await prefs.reload();
  });

  test('uses the device preference until the account preference loads', () async {
    final prefs = await SharedPrefs.getAsync();
    await prefs.setString(LocaleNotifier.preferenceKey, 'ta');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(localeProvider), const Locale('ta'));

    await container.read(localeProvider.notifier).restoreFromProfile('en');
    expect(container.read(localeProvider), const Locale('en'));
    expect(prefs.getString(LocaleNotifier.preferenceKey), 'en');
  });

  test('updates immediately and restores the previous language after a save failure', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final remote = Completer<void>();
    final change = container.read(localeProvider.notifier).selectLanguage('ta', () => remote.future);

    expect(container.read(localeProvider), const Locale('ta'));
    final failure = expectLater(change, throwsStateError);
    remote.completeError(StateError('network failure'));
    await failure;
    expect(container.read(localeProvider), const Locale('en'));
    expect((await SharedPrefs.getAsync()).getString(LocaleNotifier.preferenceKey), isNull);
  });

  testWidgets('profile changes the app locale and saves the selected language', (tester) async {
    final account = _Account();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => account)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(localeProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppDesignSurface(child: ProfileScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('தமிழ்'));
    await tester.pumpAndSettle();

    expect(account.savedLanguage, 'ta');
    expect(find.text('மொழி'), findsOneWidget);
    expect(find.text('விருப்பத்தேர்வுகள்'), findsOneWidget);
    expect(find.text('Preferences'), findsNothing);
    expect((await SharedPrefs.getAsync()).getString(LocaleNotifier.preferenceKey), 'ta');
  });
}

class _Account extends AuthNotifier {
  String? savedLanguage;

  @override
  Future<User> build() async => User(id: 'test-account', name: 'Asha Rao', email: 'asha@example.com');

  @override
  Future<void> updateLanguage(String language) async {
    savedLanguage = language;
  }
}
