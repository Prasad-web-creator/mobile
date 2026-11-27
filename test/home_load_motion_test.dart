import 'dart:async';
import 'dart:convert';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/dashboard/data/models/dashboard_stats.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/home/data/home_check_cache.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';
import 'package:claimsupport/features/home/presentation/screens/home_screen.dart';
import 'package:claimsupport/features/home/presentation/widgets/home_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _check = CheckSummary(
  id: 'a',
  treatment: 'Sample treatment',
  dateLabel: '12 Oct',
  meta: 'For you',
  statusLabel: 'Fully covered',
  statusKind: CheckStatusKind.covered,
  route: '/checks/a',
  bestPolicyName: 'Sample plan',
  policyCount: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String sessionFor(String account) {
    final claims = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'user': {'id': account},
        }),
      ),
    );
    return 'header.$claims.signature';
  }

  test('Home restores the checks and counts for the saved session only', () async {
    FlutterSecureStorage.setMockInitialValues({AppConstants.kAuthTokenKey: sessionFor('first')});
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    final cache = HomeCheckCache();
    cache.update(
      account: 'first',
      name: 'Sample User',
      checks: [_check],
      counts: (prescriptions: 3, policies: 2),
    );
    await Future<void>.delayed(Duration.zero);

    final restored = await HomeCheckCache.restore();
    expect(restored.read(null)?.checks?.single.treatment, _check.treatment);
    expect(restored.read(null)?.counts, (prescriptions: 3, policies: 2));
    await const FlutterSecureStorage().write(key: AppConstants.kAuthTokenKey, value: sessionFor('second'));
    expect((await HomeCheckCache.restore()).read(null), isNull);
  });

  testWidgets('reduce motion fades all Home elements together without translating them', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeEntrance(
          progress: AlwaysStoppedAnimation(0.5),
          reduced: true,
          child: Column(
            children: [
              HomeReveal(delay: 40, duration: 300, rise: 8, child: Text('Greeting')),
              HomeReveal(delay: 320, duration: 300, rise: 16, child: Text('Navigation')),
            ],
          ),
        ),
      ),
    );
    final reveals = find.byType(HomeReveal);
    final opacity = tester.widgetList<Opacity>(find.descendant(of: reveals, matching: find.byType(Opacity)));
    expect(opacity.map((widget) => widget.opacity), [0.5, 0.5]);
    final transforms = tester.widgetList<Transform>(
      find.descendant(of: reveals, matching: find.byType(Transform)),
    );
    expect(transforms.every((widget) => widget.transform.isIdentity()), isTrue);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'loading and loaded Home reserve the same card and documents positions in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final checks = Completer<List<CheckSummary>>();
        final stats = Completer<DashboardStats>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_NoUser.new),
              homeChecksProvider.overrideWith((ref) => checks.future),
              dashboardStatsProvider.overrideWith(() => _Stats(stats.future)),
            ],
            child: MaterialApp(
              theme: ThemeData(
                brightness: brightness,
                extensions: [
                  brightness == Brightness.dark ? AppColors.dark : AppColors.light,
                  brightness == Brightness.dark ? AppIllustrationColors.dark : AppIllustrationColors.light,
                ],
              ),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 80));
        final recent = find.text('Recent checks');
        final docs = find.text('Documents');
        final positions = (tester.getTopLeft(recent), tester.getTopLeft(docs));
        checks.complete([_check]);
        stats.complete(DashboardStats(totalPolicies: 2, totalPrescriptions: 3));
        await tester.pump();
        await tester.pumpAndSettle();
        expect((tester.getTopLeft(recent), tester.getTopLeft(docs)), positions);
        expect(find.text('Sample treatment'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _NoUser extends AuthNotifier {
  @override
  Future<User?> build() async => null;
}

class _Stats extends DashboardStatsNotifier {
  _Stats(this.result);
  final Future<DashboardStats> result;

  @override
  Future<DashboardStats> build() => result;
}
