import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/widgets/check_steps.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/core/design/widgets/floating_nav_bar.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_card.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_stack.dart';

CheckSummary _check(int i, CheckStatusKind kind, String label) => CheckSummary(
  id: '$i',
  treatment:
      'A very long treatment name that should wrap onto two lines and then end with an ellipsis',
  dateLabel: '12 Oct',
  meta: 'For Rajesh Venkatraman · Best with Prakriti Family Health Secure',
  statusLabel: label,
  statusKind: kind,
  route: '/summary/$i',
);

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: child,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final tamilFont = FontLoader('NotoSansTamil')
      ..addFont(rootBundle.load('assets/fonts/noto-tamil/NotoSansTamil.ttf'));
    await tamilFont.load();
  });
  // The new widgets read only the design-system extensions, so a minimal theme
  // avoids the legacy Inter text theme (google_fonts) in tests.
  ThemeData theme(Brightness b) => ThemeData(
    brightness: b,
    extensions: [
      b == Brightness.dark ? AppColors.dark : AppColors.light,
      b == Brightness.dark
          ? AppIllustrationColors.dark
          : AppIllustrationColors.light,
    ],
  );

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    testWidgets('Home components render without overflow ($name, 360pt wide)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var viewAllTaps = 0;
      await tester.pumpWidget(
        _app(
          theme(brightness),
          Column(
            children: [
              const CheckSteps(),
              Row(
                children: [
                  Expanded(
                    child: AppDocumentCard(
                      type: DocumentCardType.prescription,
                      count: 0,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDocumentCard(
                      type: DocumentCardType.policy,
                      count: 140,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              AppCheckStack(
                checks: [
                  _check(1, CheckStatusKind.covered, 'Covered'),
                  _check(2, CheckStatusKind.partial, 'Partially Covered'),
                  _check(3, CheckStatusKind.other, 'Manual Review Required'),
                ],
                onOpen: (_) {},
                onSeeAll: () => viewAllTaps++,
              ),
              FloatingNavBar(
                currentIndex: 0,
                onTabSelected: (_) {},
                onNewCheck: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('View claim coverage'), findsOneWidget);
      expect(find.byIcon(AppIcons.listChecks), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('New check'), findsOneWidget);

      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(viewAllTaps, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Tamil Home cards stay aligned and keep the policy visible at phone widths',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final l10n = lookupAppLocalizations(const Locale('ta'));
      const policy = 'Prakriti Family Health Secure';
      final checks = [
        for (final (id, kind) in [
          (1, CheckStatusKind.covered),
          (2, CheckStatusKind.failed),
        ])
          CheckSummary(
            id: '$id',
            treatment: 'Acute Appendicitis with Appendicolith',
            patientName: 'Rajesh',
            dateLabel: l10n.sharedToday,
            meta: '',
            statusLabel: 'Fully covered',
            statusKind: kind,
            bestPolicyName: policy,
            policyCount: 1,
            route: '/summary/$id',
          ),
      ];
      for (final (width, scale) in [(360.0, 1.0), (320.0, 2.0)]) {
        tester.view.physicalSize = Size(width, 850);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ta'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      AppCheckStack(
                        checks: checks,
                        glass: true,
                        cardHeight: AppCheckCard.stackHeight(context, checks),
                        onOpen: (_) {},
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: AppDocumentCard(
                              type: DocumentCardType.prescription,
                              count: 3,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppDocumentCard(
                              type: DocumentCardType.policy,
                              count: 4,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      FloatingNavBar(
                        currentIndex: 0,
                        onTabSelected: (_) {},
                        onNewCheck: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(policy).hitTestable(), findsWidgets);
        expect(
          tester.getTopLeft(find.text(l10n.sharedPrescriptions)).dy,
          closeTo(tester.getTopLeft(find.text(l10n.sharedPolicies)).dy, 0.5),
        );
        expect(
          tester.getTopLeft(find.text('3')).dy,
          closeTo(tester.getTopLeft(find.text('4')).dy, 0.5),
        );
      }
    },
  );
}
