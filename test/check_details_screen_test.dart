import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/summary/data/check_details_repository.dart';
import 'package:claimsupport/features/summary/data/policy_evidence.dart';
import 'package:claimsupport/features/summary/presentation/screens/check_details_screen.dart';
import 'package:claimsupport/features/summary/presentation/widgets/policy_continuity_card.dart';

class _FixtureRepository extends CheckDetailsRepository {
  _FixtureRepository(this.group) : super(client: Dio());

  final AnalysisReportGroup group;

  @override
  Future<AnalysisReportGroup> loadGroup(String groupId) async => group;

  @override
  Future<Map<String, dynamic>?> loadReport(String id) async {
    final first = id == 'report-prakriti';
    return {
      'overallStatus': first ? 'Covered' : 'Partially covered',
      if (first)
        'policyContinuity': {
          'status': 'Continuity Verified',
          'statusCode': 'VERIFIED',
          'originalPolicyStartDate': '2024-10-12',
        },
      'policyJson': first ? {'policyName': 'Uploaded Policy'} : {'planName': 'Sehat'},
      'policyText': 'Medically necessary, inpatient care is covered.\nRoom rent is subject to plan limits.',
      if (group.diagnosis.isNotEmpty)
        'prescriptionJson': {
          'diagnosis': group.diagnosis,
          'patientName': 'Rajesh',
          'visitDate': '2025-10-12',
        },
      'comparison': [
        {
          'itemType': 'Procedure',
          'item': first ? 'Appendectomy' : 'Laparoscopic surgery',
          'coverageStatus': first ? 'Covered' : 'Partially Covered',
          'coverageStatusReason': 'This item meets the hospitalisation rules.',
          'policyClauses': [
            {
              'decisive': true,
              'section': 'Hospitalisation',
              'quote': 'Medically necessary inpatient care is covered.',
              'effect': 'Coverage',
              'explanation': 'The treatment requires inpatient care.',
            },
            {
              'decisive': false,
              'section': 'Room rent',
              'quote': 'Room rent is subject to plan limits.',
              'effect': 'Limit',
              'explanation': 'The room entitlement was considered.',
            },
          ],
        },
        {
          'item': 'Diagnostic tests',
          'coverageStatus': 'Needs Verification',
          'coverageStatusReason': 'The insurer may request an itemised bill.',
        },
      ],
      'coverageAnalysis': {
        'comparison': [
          {'item': 'Superseded comparison'},
        ],
      },
    };
  }

  @override
  Future<String?> loadPolicyProductName(String policyId) async => policyId == 'p-1' ? 'Prakriti' : null;

  @override
  Future<CheckDocumentDetails> loadTreatment(AnalysisReportGroup group) async => const CheckDocumentDetails(
    fields: [('Doctor', 'Dr. Ananya Rao')],
    listField: ('Items', ['Appendectomy']),
  );

  @override
  Future<CheckDocumentDetails> loadPolicy(PolicyReportRow row) async =>
      CheckDocumentDetails(fields: [('Insurer', row.insuranceCompany), ('Sum insured', '₹5,00,000')]);
}

AnalysisReportGroup _group({
  bool secondPolicy = true,
  bool includeTreatment = true,
  bool secondReport = true,
}) => AnalysisReportGroup.fromJson({
  'groupId': 'check-1',
  'groupType': secondPolicy ? 'multi' : 'single',
  'status': 'completed',
  'createdAt': DateTime(2025, 10, 12, 22, 55).toUtc().toIso8601String(),
  'prescriptionId': includeTreatment ? 'rx-1' : '',
  if (includeTreatment)
    'prescription': {'patientName': 'Rajesh', 'diagnosis': 'Appendicitis with planned laparoscopic surgery'},
  'comparisonSummary': {'bestPolicyId': 'p-1'},
  'policyReports': [
    {
      'policyId': 'p-1',
      'reportId': 'report-prakriti',
      'policyName': 'Uploaded Policy',
      'insuranceCompany': 'Prakriti Health',
      'status': 'completed',
      'overallStatus': 'Covered',
    },
    if (secondPolicy)
      {
        'policyId': 'p-2',
        if (secondReport) 'reportId': 'report-sehat',
        'policyName': secondReport ? 'Uploaded Policy' : 'Sehat',
        'insuranceCompany': 'Sehat Insurance',
        'status': 'completed',
        'overallStatus': 'Partially covered',
        'reasons': ['Reason one', 'Reason two', 'Reason three', 'Reason four'],
      },
  ],
});

Future<void> _pump(WidgetTester tester, Brightness brightness, AnalysisReportGroup group) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(bottom: 24);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [checkDetailsRepositoryProvider.overrideWithValue(_FixtureRepository(group))],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: brightness,
          extensions: [
            brightness == Brightness.dark ? AppColors.dark : AppColors.light,
            brightness == Brightness.dark ? AppIllustrationColors.dark : AppIllustrationColors.light,
          ],
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const CheckDetailsScreen(groupId: 'check-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, files) in <(String, List<String>)>[
      ('Geist', ['Geist-Regular', 'Geist-Medium', 'Geist-SemiBold', 'Geist-Bold']),
      ('PhosphorRegular', ['phosphor/Phosphor']),
    ]) {
      final loader = FontLoader(family);
      for (final name in files) {
        loader.addFont(rootBundle.load('assets/fonts/$name.ttf'));
      }
      await loader.load();
    }
  });

  for (final brightness in Brightness.values) {
    final suffix = brightness.name;
    testWidgets('renders the selected report and clause sections in $suffix', (tester) async {
      await _pump(tester, brightness, _group());
      expect(find.text('2 policies checked'), findsOneWidget);
      expect(find.text('Rajesh · 12 Oct 2025   10 : 55 PM'), findsOneWidget);
      expect(find.text('Prakriti covers this treatment.'), findsOneWidget);
      expect(find.text('Uploaded Policy'), findsNothing);
      expect(find.text('Policy evidence'), findsNothing);
      expect(find.text('Superseded comparison'), findsNothing);
      expect(find.bySemanticsLabel('Share'), findsNothing);
      expect(find.text('Best'), findsOneWidget);
      final continuity = find.byType(PolicyContinuityCard);
      expect(continuity, findsOneWidget);
      expect(find.descendant(of: continuity, matching: find.text('Continuity Verified')), findsWidgets);
      expect(
        tester.getTopLeft(continuity).dy,
        greaterThan(tester.getBottomRight(find.text('Diagnostic tests')).dy),
      );
      expect(tester.getBottomRight(continuity).dy, lessThan(tester.getTopLeft(find.text('Documents')).dy));

      final firstLink = find.bySemanticsLabel('See policy clauses (2)');
      await tester.dragUntilVisible(firstLink.hitTestable(), find.byType(ListView), const Offset(0, -180));
      await tester.tap(firstLink);
      await tester.pumpAndSettle();
      expect(find.text('Deciding clauses · 1'), findsOneWidget);
      expect(find.text('Also considered · 1'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data == '\u201cMedically necessary, inpatient care is covered.\u201d',
        ),
        findsOneWidget,
      );
      expect(find.text('Hospitalisation'), findsOneWidget);
      expect(find.text('Room rent'), findsOneWidget);
      expect(tester.getBottomRight(find.byType(BottomSheet)).dy, 844);
      final panel = find.ancestor(of: find.text('Policy clauses'), matching: find.byType(Material)).first;
      expect(tester.getBottomRight(panel).dy, lessThanOrEqualTo(820));
      Navigator.of(tester.element(find.text('Policy clauses'))).pop();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Sehat, Partially covered').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Sehat covers part of this treatment.'), findsOneWidget);
      expect(find.text('Laparoscopic surgery'), findsOneWidget);
      expect(continuity, findsNothing);

      final link = find.bySemanticsLabel('See policy clauses (2)');
      await tester.dragUntilVisible(link.hitTestable(), find.byType(ListView), const Offset(0, -180));
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('Deciding clauses · 1'), findsOneWidget);
      expect(find.text('Also considered · 1'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Deciding clauses · 1')).dy,
        lessThan(tester.getTopLeft(find.text('Also considered · 1')).dy),
      );
      Navigator.of(tester.element(find.text('Policy clauses'))).pop();
      await tester.pumpAndSettle();

      final second = find.text('Diagnostic tests');
      await tester.ensureVisible(second);
      await tester.pumpAndSettle();
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(find.text('The insurer may request an itemised bill.'), findsOneWidget);
      expect(find.text('Policy evidence'), findsNothing);
      expect(find.text('This item meets the hospitalisation rules.'), findsNothing);
      final emptyLink = find.bySemanticsLabel('See policy clauses');
      await tester.dragUntilVisible(emptyLink.hitTestable(), find.byType(ListView), const Offset(0, -120));
      await tester.tap(emptyLink);
      await tester.pumpAndSettle();
      expect(find.text('Exact policy wording is unavailable for this term.'), findsOneWidget);
      expect(find.text('Analysis basis'), findsOneWidget);
      expect(
        find.widgetWithText(SelectableText, 'The insurer may request an itemised bill.'),
        findsOneWidget,
      );
      Navigator.of(tester.element(find.text('Policy clauses'))).pop();
      await tester.pumpAndSettle();

      final treatment = find.text('Treatment document');
      await tester.dragUntilVisible(treatment.hitTestable(), find.byType(ListView), const Offset(0, -160));
      await tester.tap(treatment);
      await tester.pumpAndSettle();
      expect(find.text('Dr. Ananya Rao'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
      expect(find.text('Appendectomy'), findsOneWidget);
      Navigator.of(tester.element(find.text('Dr. Ananya Rao'))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('recovers only the policy passages cited by a saved item', () {
    const hospitalisation = 'C.1 In-patient Hospitalisation. The Company pays eligible medical expenses.';
    const roomRent = 'C.1.1 Room Rent Limit. Room rent is payable up to 1% of Sum Insured per day.';
    const exclusions = 'D.2 Specified diseases (Code - Excl02). A waiting period of 24 months applies.';
    final evidence = PolicyEvidence('''--- PAGE 3 ---
Section C.1
Exclusions
--- PAGE 5 ---
$hospitalisation
$roomRent
C.2 Day Care. Eligible costs are covered.
$exclusions
--- PAGE 6 ---
Unrelated text.
''');

    expect(
      evidence.clausesFor({
        'coverageStatusReason': 'Room rent is covered under Section C.1 and Section C.11.',
        'policyEvidence': 'The limit is "Rs. 10,000 for any room".',
      }),
      [
        {'section': 'C.1', 'quote': hospitalisation},
        {'section': 'C.1.1', 'quote': roomRent},
      ],
    );
    expect(evidence.clausesFor({'verificationClause': 'Excl02'}), [
      {'section': 'D.2', 'quote': exclusions},
    ]);
    expect(evidence.clausesFor({'coverageStatusReason': 'C.10 applies.'}), isEmpty);
  });

  testWidgets('a single policy uses one card and missing reports do not show another result', (tester) async {
    await _pump(tester, Brightness.light, _group(secondPolicy: false, includeTreatment: false));
    expect(find.text('1 policy checked'), findsOneWidget);
    expect(find.bySemanticsLabel('Sehat, Partially covered'), findsNothing);
    expect(find.text('Prakriti covers this treatment.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, Brightness.light, _group(secondReport: false));
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Sehat, Partially covered').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Sehat covers part of this treatment.'), findsOneWidget);
    expect(find.text('Appendectomy'), findsNothing);
    expect(find.text('What was checked'), findsNothing);
  });

  test('older API deployments can still open durable job results by ID', () async {
    final client = Dio();
    addTearDown(client.close);
    final requested = <String>[];
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requested.add(request.path);
          if (request.path == '/analysis/grouped/check-42') {
            handler.reject(
              DioException.badResponse(
                statusCode: 404,
                requestOptions: request,
                response: Response<Object?>(requestOptions: request, statusCode: 404),
              ),
            );
            return;
          }
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: request,
              data: {
                'id': 'check-42',
                'status': 'completed',
                'result': {
                  'prescriptionId': 'rx-1',
                  'comparisonSummary': {'bestPolicyId': 'p-1'},
                  'policyAnalyses': [
                    {'policyId': 'p-1', 'reportId': 'report-1', 'overallStatus': 'Covered'},
                  ],
                },
              },
            ),
          );
        },
      ),
    );
    final result = await CheckDetailsRepository(client: client).loadGroup('check-42');
    expect(requested, ['/analysis/grouped/check-42', '/analysis/jobs/check-42']);
    expect(result.isDurableJob, isTrue);
    expect(result.reportIds, ['report-1']);
    expect(result.bestPolicyId, 'p-1');
    expect(result.prescriptionId, 'rx-1');
  });
}
