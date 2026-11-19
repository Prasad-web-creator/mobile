import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/benefits/data/models/policy_benefits.dart';
import 'package:claimsupport/features/benefits/presentation/controllers/benefits_controller.dart';
import 'package:claimsupport/features/benefits/presentation/screens/my_benefits_screen.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';

// Real responses of GET /policies/{id}/benefits (holder names anonymised).
const _prakriti = '6afeb74f917e1463c734bfe1';
const _evergreen = '6afeb0a0917e1463c734bfd5';
const _noDetailsYet = '6afea19c917e1463c734bfac';

PolicyBenefits _fixture(String id) => PolicyBenefits.fromJson(
      jsonDecode(File('test/fixtures/benefits_$id.json').readAsStringSync()) as Map<String, dynamic>,
    );

Policy _policy(String id, String name, String number) =>
    Policy(id: id, policyNumber: number, policyName: name, insuranceCompany: 'Insurer', status: 'Active');

Future<void> _pump(WidgetTester tester, List<Policy> policies,
    {ThemeData? theme, Map<String, PolicyBenefits>? data, int hidden = 0}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      benefitsPoliciesProvider.overrideWith((ref) async => BenefitsPolicyList(ready: policies, total: policies.length + hidden)),
      policyBenefitsProvider.overrideWith((ref, id) async => (data ?? {})[id] ?? _fixture(id)),
    ],
    child: MaterialApp(theme: theme ?? AppTheme.lightTheme, home: const MyBenefitsScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.dragUntilVisible(find.text(text), find.byType(ListView), const Offset(0, -200));
  await tester.pumpAndSettle();
  // Bring it clear of the screen edge so it can be tapped.
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('single policy is auto-selected and its stored benefits are shown', (tester) async {
    await _pump(tester, [_policy(_evergreen, 'Evergreen Health Plus', 'EGI/HP/26/1187604')]);

    expect(find.text('Your policy'), findsOneWidget);
    expect(find.text('Evergreen Health Plus'), findsWidgets);
    expect(find.text('EGI/HP/26/1187604'), findsWidgets);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('₹30,00,000'), findsOneWidget);
    // Co-payment is mentioned without a percentage: say it applies, don't invent one.
    expect(find.text('Applies'), findsOneWidget);
    expect(find.text('Not specified'), findsWidgets); // deductible
    await _scrollTo(tester, 'Pre-existing diseases');
    expect(find.text('36 months'), findsOneWidget);
    await _scrollTo(tester, 'Ambulance');
    expect(find.text('₹5,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching policy replaces all benefit data', (tester) async {
    await _pump(tester, [
      _policy(_evergreen, 'Evergreen Health Plus', 'EGI/HP/26/1187604'),
      _policy(_prakriti, 'Prakriti Family Health Secure', 'PGI/HL/26/4410287'),
    ]);
    expect(find.text('₹30,00,000'), findsOneWidget);

    await tester.tap(find.text('Select your policy'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing); // label is not the trigger
    await tester.tap(find.text('Evergreen Health Plus').first);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(2));
    // The menu matches the field width instead of spanning the screen.
    expect(tester.getSize(find.byType(MenuItemButton).first).width, lessThanOrEqualTo(360 - 2 * 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prakriti Family Health Secure').last);
    await tester.pumpAndSettle();

    expect(find.text('₹10,00,000'), findsOneWidget);
    expect(find.text('₹30,00,000'), findsNothing);
    expect(find.text('Evergreen Health Plus'), findsNothing);
    await _scrollTo(tester, 'Room rent');
    expect(find.text('1% of SI / day'), findsOneWidget);
    await _scrollTo(tester, 'Pre-existing diseases');
    expect(find.text('36 months'), findsOneWidget);
    expect(find.text('Specific illnesses & treatments'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('policy without stored details shows a friendly message', (tester) async {
    final empty = PolicyBenefits.fromJson({
      'policyId': _noDetailsYet,
      'overview': {'policyNumber': null, 'startDate': null, 'endDate': null},
      'hasDetails': false,
      'keyBenefits': {},
      'waitingPeriods': {'periods': []},
      'conditions': {},
    });
    await _pump(tester, [_policy(_noDetailsYet, 'Uploaded Policy', '')], data: {_noDetailsYet: empty});
    expect(find.text('Benefit details not available yet'), findsOneWidget);
    expect(find.text('Dates not available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no policies shows an empty state without asking to upload', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No policies yet'), findsOneWidget);
    expect(find.text('Upload Policy'), findsNothing);
  });

  testWidgets('dark theme renders the full page without overflow', (tester) async {
    await _pump(tester, [_policy(_prakriti, 'Prakriti Family Health Secure', 'PGI/HL/26/4410287')], theme: AppTheme.darkTheme);
    await _scrollTo(tester, 'Important Conditions');
    await tester.tap(find.textContaining('Not covered ('));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('policy wording sheet shows stored text without inventing a page reference', (tester) async {
    await _pump(tester, [_policy(_prakriti, 'Prakriti Family Health Secure', 'PGI/HL/26/4410287')]);
    await _scrollTo(tester, 'Room rent');
    // Only the explicit button opens the wording; tapping the title does nothing.
    await tester.tap(find.text('Room rent').first);
    await tester.pumpAndSettle();
    expect(find.text('Policy wording'), findsNothing);
    final button = find.descendant(
      of: find.ancestor(of: find.text('Room rent').first, matching: find.byType(Column)).first,
      matching: find.text('View policy condition'),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Policy wording'), findsOneWidget);
    expect(find.textContaining('Page reference not available'), findsOneWidget);
  });

  testWidgets('deductible info icon always explains the term', (tester) async {
    await _pump(tester, [_policy(_prakriti, 'Prakriti Family Health Secure', 'PGI/HL/26/4410287')]);
    for (final title in ['Co-payment', 'Deductible']) {
      final card = find.ancestor(of: find.text(title), matching: find.byType(AppCard)).first;
      expect(find.descendant(of: card, matching: find.byIcon(Icons.info_outline_rounded)), findsOneWidget);
    }
    await _scrollTo(tester, 'Deductible');
    await tester.tap(find.text('Deductible'));
    await tester.pumpAndSettle();
    expect(find.text('What this means'), findsOneWidget);
    expect(find.textContaining('not stated in the details'), findsOneWidget);
  });

  testWidgets('waiting period duration is pinned to the right edge', (tester) async {
    await _pump(tester, [_policy(_prakriti, 'Prakriti Family Health Secure', 'PGI/HL/26/4410287')]);
    await _scrollTo(tester, 'Initial waiting period');
    final title = tester.getTopLeft(find.text('Initial waiting period'));
    final value = tester.getTopRight(find.text('30 days'));
    final card = tester.getTopRight(find.ancestor(of: find.text('30 days'), matching: find.byType(AppCard)).first);
    expect(title.dx, lessThan(60));
    expect(card.dx - value.dx, lessThan(24));
  });

  testWidgets('policies without benefit details are not offered', (tester) async {
    await _pump(tester, const [], hidden: 2);
    expect(find.text('Benefit details not available yet'), findsOneWidget);
    expect(find.text('No policies yet'), findsNothing);
  });

  test('only policies with stored benefit details qualify', () {
    final skeleton = {'coveredTreatments': [], 'subLimits': [], 'specialConditions': []};
    expect(policyHasBenefitDetails({'extractedPolicyJson': skeleton}), isFalse);
    expect(policyHasBenefitDetails({'extractedPolicyJson': {}}), isFalse);
    expect(policyHasBenefitDetails({}), isFalse);
    expect(policyHasBenefitDetails({'extractedPolicyJson': {'coPay': ''}}), isFalse);
    expect(policyHasBenefitDetails({'extractedPolicyJson': {'coverageAmount': 1000000}}), isTrue);
    expect(policyHasBenefitDetails({'extractedPolicyJson': {'coveredTreatments': ['Cataract']}}), isTrue);
  });
}
