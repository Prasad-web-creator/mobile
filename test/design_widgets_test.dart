import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/widgets/check_steps.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/core/design/widgets/floating_nav_bar.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_stack.dart';

CheckSummary _check(int i, CheckStatusKind kind, String label) => CheckSummary(
  id: '$i',
  treatment: 'A very long treatment name that should wrap onto two lines and then end with an ellipsis',
  dateLabel: '12 Oct',
  meta: 'For Rajesh Venkatraman · Best with Prakriti Family Health Secure',
  statusLabel: label,
  statusKind: kind,
  route: '/summary/$i',
);

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: child),
  ),
);

void main() {
  // The new widgets read only the design-system extensions, so a minimal theme
  // avoids the legacy Inter text theme (google_fonts) in tests.
  ThemeData theme(Brightness b) => ThemeData(
    brightness: b,
    extensions: [
      b == Brightness.dark ? AppColors.dark : AppColors.light,
      b == Brightness.dark ? AppIllustrationColors.dark : AppIllustrationColors.light,
    ],
  );

  for (final (name, brightness) in [('light', Brightness.light), ('dark', Brightness.dark)]) {
    testWidgets('Home components render without overflow ($name, 360pt wide)', (tester) async {
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
                    child: AppDocumentCard(type: DocumentCardType.prescription, count: 0, onTap: () {}),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDocumentCard(type: DocumentCardType.policy, count: 140, onTap: () {}),
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
              FloatingNavBar(currentIndex: 0, onTabSelected: (_) {}, onNewCheck: () {}),
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
}
