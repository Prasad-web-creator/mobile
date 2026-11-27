import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/core/design/widgets/floating_nav_bar.dart';
import 'package:claimsupport/core/design/widgets/home_background.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/core/routing/app_router.dart';
import 'package:claimsupport/core/services/admob_service.dart';
import 'package:claimsupport/features/analyses_reports/presentation/screens/analyses_reports_screen.dart';
import 'package:claimsupport/features/analysis/data/repositories/new_check_repository.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/dashboard/data/models/dashboard_stats.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/documents/presentation/document_summary.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final (family, files) in <(String, List<String>)>[
      ('Geist', ['Geist-Regular', 'Geist-Medium', 'Geist-SemiBold', 'Geist-Bold']),
      ('PhosphorRegular', ['phosphor/Phosphor']),
      ('PhosphorFill', ['phosphor/Phosphor-Fill']),
    ]) {
      final loader = FontLoader(family);
      for (final name in files) {
        loader.addFont(rootBundle.load('assets/fonts/$name.ttf'));
      }
      await loader.load();
    }
  });

  test('Phase F §0.2 tokens: light page is #F3F4F6 and home is #FFFFFF', () {
    expect(AppColors.light.backgroundPage, const Color(0xFFF3F4F6));
    expect(AppColors.light.backgroundHome, const Color(0xFFFFFFFF));
    expect(AppColors.dark.backgroundPage, const Color(0xFF101011));
    expect(AppColors.dark.backgroundHome, const Color(0xFF0D0D0E));
  });

  test('Phase F §0.3 list titles never expose raw filenames', () {
    final rxWithFile = Prescription.fromJson({
      '_id': '1',
      'diagnosis': 'Navyug_Health_Plus_Policy_NHI-12345.pdf',
      'originalFileName': 'Navyug_Health_Plus_Policy_NHI-12345.pdf',
    });
    expect(DocumentSummary.prescription(rxWithFile).title, 'Prescription');

    final rxExtracted = Prescription.fromJson({
      '_id': '2',
      'diagnosis': 'Acute Appendicitis',
      'originalFileName': 'presc_scan_001.pdf',
    });
    expect(DocumentSummary.prescription(rxExtracted).title, 'Acute Appendicitis');

    final policyWithFileOnly = Policy.fromJson({
      '_id': 'p1',
      'policyName': 'Uploaded Policy',
      'originalFileName': 'Navyug_Health_Plus_Policy_NHI-12345.pdf',
    });
    expect(DocumentSummary.policy(policyWithFileOnly).title, 'Policy');

    final policyExtracted = Policy.fromJson({
      '_id': 'p2',
      'policyName': 'Navyug Health Plus',
      'insuranceCompany': 'Navyug General Insurance',
      'originalFileName': 'Navyug_Health_Plus_Policy_NHI-12345.pdf',
    });
    expect(DocumentSummary.policy(policyExtracted).title, 'Navyug Health Plus');
  });

  test('prescription selection formats the saved timestamp and uses a date-only fallback', () {
    final today = DateTime(2026, 11, 26, 20);
    final typed = Prescription.fromJson({
      'id': 'typed',
      'isManual': true,
      'extractedPrescriptionText': 'Sample treatment',
      'createdAt': DateTime(2026, 11, 26, 15, 35).toUtc().toIso8601String(),
    });
    final priorVisit = Prescription.fromJson({
      'id': 'uploaded',
      'patientName': 'Sample patient',
      'visitDate': '2026-11-25',
    });

    final summary = DocumentSummary.prescription(typed, now: today);
    expect(summary.meta, 'Typed by you');
    expect(summary.timestamp, 'Today   03 : 35 PM');
    final fallback = DocumentSummary.prescription(priorVisit, now: today);
    expect(fallback.meta, 'For Sample patient');
    expect(fallback.timestamp, '25 Nov 2026');
  });

  testWidgets('Phase F §0.4 document row uses mini illustration in 48x48 radius-14 tile', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(brightness),
          theme: ThemeData(
            brightness: brightness,
            extensions: [
              brightness == Brightness.dark ? AppColors.dark : AppColors.light,
              brightness == Brightness.dark ? AppIllustrationColors.dark : AppIllustrationColors.light,
            ],
          ),
          home: Scaffold(
            body: AppDocumentRow(
              type: DocumentCardType.prescription,
              title: 'Acute Appendicitis',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(AppIllustration), findsOneWidget);
      final tile = tester.widget<SizedBox>(
        find.ancestor(of: find.byType(AppIllustration), matching: find.byType(SizedBox)).first,
      );
      expect(tile.width, 48);
      expect(tile.height, 48);
      final decorated = tester.widget<DecoratedBox>(
        find.ancestor(of: find.byType(AppIllustration), matching: find.byType(DecoratedBox)).first,
      );
      final shape = decorated.decoration as ShapeDecoration;
      expect(shape.color, brightness == Brightness.dark ? Colors.transparent : const Color(0xFFF4F6FA));
    }
  });

  testWidgets(
    'Phase F §0.1 & §0.9: HomeBackground only on Home, shared nav preserves History cache without spinner',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final adsEnabled = AdMobConfig.isEnabled;
      AdMobConfig.setEnabled(false);
      addTearDown(() => AdMobConfig.setEnabled(adsEnabled));

      final historyNotifier = _FakeHistoryNotifier();
      final router = AppRouter.router;
      router.go('/dashboard');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestUser.new),
            homeChecksProvider.overrideWith((ref) async => []),
            dashboardStatsProvider.overrideWith(_TestDashboard.new),
            analysisReportProvider.overrideWith(() => historyNotifier),
            checkTreatmentsProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp.router(
            theme: ThemeData(
              brightness: Brightness.light,
              extensions: const [AppColors.light, AppIllustrationColors.light],
            ),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Home has HomeBackground (hitTestable), nav is present at 16px insets.
      expect(find.byType(HomeBackground), findsOneWidget);
      final navElement = tester.element(find.byType(FloatingNavBar));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).hitTestable().first);
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

      // Switch to History: same FloatingNavBar element persists!
      await tester.tap(find.bySemanticsLabel('History'));
      await tester.pumpAndSettle();
      expect(identical(tester.element(find.byType(FloatingNavBar)), navElement), isTrue);

      // History uses plain light page #F3F4F6 and has NO HomeBackground.
      final historyScaffold = tester.widget<Scaffold>(find.byType(Scaffold).hitTestable().first);
      expect(historyScaffold.backgroundColor, const Color(0xFFF3F4F6));
      expect(find.byType(HomeBackground).hitTestable(), findsNothing);
      expect(find.text('Appendicitis check'), findsOneWidget);

      // Switch back to Home and back to History: no loading skeleton ever appears!
      await tester.tap(find.bySemanticsLabel('Home'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('History'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Appendicitis check'), findsOneWidget);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Phase F §0.9: History delete removes row in-place without reloading whole list', (
    tester,
  ) async {
    final notifier = _FakeHistoryNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestUser.new),
          analysisReportProvider.overrideWith(() => notifier),
        ],
        child: const MaterialApp(home: AnalysesReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Appendicitis check'), findsOneWidget);
    final initialFetches = notifier.fetches;

    await notifier.deleteReports(['g1']);
    await tester.pump();
    expect(find.text('Appendicitis check'), findsNothing);
    expect(find.text('No checks yet'), findsOneWidget);
    expect(notifier.fetches, initialFetches);
  });
}

class _TestUser extends AuthNotifier {
  @override
  Future<User?> build() async =>
      User.fromJson({'id': 'user-1', 'name': 'Priya Nair', 'email': 'priya@example.test'});
}

class _TestDashboard extends DashboardStatsNotifier {
  @override
  Future<DashboardStats> build() async =>
      DashboardStats(totalPolicies: 2, totalPrescriptions: 1);
}

class _FakeHistoryNotifier extends AnalysisReportNotifier {
  int fetches = 0;
  final List<AnalysisReportGroup> _items = [
    AnalysisReportGroup.fromJson({
      'groupId': 'g1',
      'status': 'completed',
      'createdAt': '2026-11-20T10:00:00Z',
      'prescription': {'diagnosis': 'Appendicitis check', 'patientName': 'Priya Nair'},
      'policyReports': [
        {'policyName': 'Prakriti Health', 'overallStatus': 'Covered'},
      ],
    }),
  ];

  @override
  Future<PaginationResponse<AnalysisReportGroup>> fetchPage(int page) async {
    fetches++;
    return PaginationResponse(
      docs: List.of(_items),
      totalDocs: _items.length,
      limit: 10,
      totalPages: 1,
      page: 1,
      hasPrevPage: false,
      hasNextPage: false,
    );
  }

  @override
  Future<int> deleteReports(List<String> groupIds) async {
    _items.removeWhere((g) => groupIds.contains(g.groupId));
    removeLocally((g) => groupIds.contains(g.groupId));
    return groupIds.length;
  }
}
