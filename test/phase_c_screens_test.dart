import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_choices.dart';
import 'package:claimsupport/core/design/widgets/app_status.dart';
import 'package:claimsupport/core/design/app_check_status.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/floating_nav_bar.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/core/theme/theme_provider.dart';
import 'package:claimsupport/features/analyses_reports/presentation/screens/analyses_reports_screen.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_card.dart';
import 'package:claimsupport/features/checks/presentation/check_completion_monitor.dart';
import 'package:claimsupport/features/checks/presentation/check_notifications.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/policies/presentation/screens/policy_list_screen.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:claimsupport/features/prescriptions/presentation/screens/prescription_list_screen.dart';
import 'package:claimsupport/features/profile/presentation/screens/profile_screen.dart';
import 'package:claimsupport/features/profile/presentation/screens/edit_name_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _page = _results([
  _check('sept', 'Ear review', '2026-09-17', 'Not Covered'),
  _check('oct', 'Knee consultation', '2026-10-06', 'Covered'),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (name, files) in <(String, List<String>)>[
      ('Geist', ['Geist-Regular', 'Geist-Medium', 'Geist-SemiBold', 'Geist-Bold']),
      ('GeistMono', ['GeistMono-Regular']),
      ('PhosphorRegular', ['phosphor/Phosphor']),
      ('PhosphorFill', ['phosphor/Phosphor-Fill']),
    ]) {
      final loader = FontLoader(name);
      for (final asset in files) {
        loader.addFont(rootBundle.load('assets/fonts/$asset.ttf'));
      }
      await loader.load();
    }
  });
  for (final brightness in Brightness.values) {
    final suffix = brightness.name;
    testWidgets('history groups, filters and retains saved checks offline in $suffix', (tester) async {
      _phone(tester);
      final backend = _Checks();
      await tester.pumpWidget(
        _app(
          brightness,
          ProviderScope(
            overrides: [analysisReportProvider.overrideWith(() => backend)],
            child: const AnalysesReportsScreen(),
          ),
        ),
      );
      await _prepare(tester, brightness);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.byType(AppCheckRow), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('October 2026')).dy,
        lessThan(tester.getTopLeft(find.text('September 2026')).dy),
      );
      expect(find.byType(FloatingNavBar), findsNothing);

      await tester.tap(find.bySemanticsLabel('Partially covered').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('No checks match this filter.'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('All').hitTestable());
      await tester.pumpAndSettle();

      backend.offline = true;
      await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
      await tester.pumpAndSettle();
      expect(find.text("You're offline. Showing saved checks."), findsOneWidget);
      expect(find.text('Knee consultation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('document lists display real extracted items and members in $suffix', (tester) async {
      _phone(tester);
      Widget screen(Widget child) => _app(
        brightness,
        ProviderScope(
          overrides: [
            policiesProvider.overrideWith(_Policies.new),
            prescriptionProvider.overrideWith(_Prescriptions.new),
          ],
          child: child,
        ),
      );
      await tester.pumpWidget(screen(const PrescriptionListScreen()));
      await _prepare(tester, brightness);
      expect(find.text('1 saved'), findsOneWidget);
      expect(find.byType(FloatingNavBar), findsNothing);
      await tester.tap(find.byType(AppDocumentRow));
      await tester.pumpAndSettle();
      expect(find.text('Dr. Sen'), findsOneWidget);
      _expectStackedLabels(tester, ['Items', 'Naproxen', 'X-ray']);
      expect(find.text('Treatment date'), findsOneWidget);
      expect(find.descendant(of: find.byType(AppSheet), matching: find.text('6 Oct 2026')), findsOneWidget);
      expect(find.text('Hospital'), findsNothing);
      expect(find.text('View document'), findsNothing);
      Navigator.of(tester.element(find.byType(AppSheet))).pop();
      await tester.pumpAndSettle();

      await tester.pumpWidget(screen(const PolicyListScreen()));
      await _prepare(tester, brightness);
      expect(find.text('1 saved'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      await tester.tap(find.byType(AppDocumentRow));
      await tester.pumpAndSettle();
      final number = tester.widget<SelectableText>(find.widgetWithText(SelectableText, 'PN-2468'));
      expect(number.style?.fontFamily, 'GeistMono');
      _expectStackedLabels(tester, ['Members', 'Asha Rao', 'Raj Rao']);
      expect(find.text('₹5,00,000'), findsOneWidget);
      expect(find.text('1 Feb 2000 – 3 Feb 2001'), findsOneWidget);
      expect(find.text('Renewal'), findsOneWidget);
      expect(find.text('Continuity'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile offers System, Light, Dark and logout confirmation in $suffix', (tester) async {
      _phone(tester);
      final mode = _PreviewTheme(brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark);
      final notifications = _ProfileNotifications();
      addTearDown(notifications.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Account.new),
            themeProvider.overrideWith(() => mode),
            checkNotificationsProvider.overrideWithValue(notifications),
          ],
          child: _app(brightness, const ProfileScreen()),
        ),
      );
      await _prepare(tester, brightness);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      expect(find.text('Edit name'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Delete account'), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(notifications.enabled.value, isFalse);
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AppSheet), matching: find.text('System')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppSheet), matching: find.text('Light')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppSheet), matching: find.text('Dark')), findsOneWidget);
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(mode.chosen, ThemeMode.system);
      Navigator.of(tester.element(find.byType(AppSheet))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Log out'));
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('History scrolls filters horizontally and filters by any policy result', (tester) async {
    _phone(tester);
    final multi = AnalysisReportGroup.fromJson({
      'groupId': 'three-policies',
      'groupType': 'multi',
      'policyCount': 3,
      'status': 'completed',
      'createdAt': '2026-11-26',
      'prescription': {'diagnosis': 'Three-policy example'},
      'comparisonSummary': {'bestPolicyId': 'p1'},
      'policyReports': [
        {'policyId': 'p1', 'policyName': 'Plan one', 'overallStatus': 'Covered'},
        {'policyId': 'p2', 'policyName': 'Plan two', 'overallStatus': 'Partially Covered'},
        {'policyId': 'p3', 'policyName': 'Plan three', 'overallStatus': 'Needs Verification'},
      ],
    });
    await tester.pumpWidget(
      _app(
        Brightness.dark,
        ProviderScope(
          overrides: [
            analysisReportProvider.overrideWith(() => _Checks(_results([multi, ..._page.docs]))),
          ],
          child: const AnalysesReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final filters = find.byType(AppFilterChips);
    final row = find.ancestor(of: find.text('Three-policy example'), matching: find.byType(AppCheckRow));
    for (final label in ['Fully covered', '3 policies compared', 'Plan one', '+2']) {
      expect(find.descendant(of: row, matching: find.text(label)), findsOneWidget);
    }
    for (final label in ['Partially covered', 'Needs verification', 'Plan two', 'Plan three']) {
      expect(find.descendant(of: row, matching: find.text(label)), findsNothing);
    }
    final dot = tester.widget<AppStatusDot>(find.descendant(of: row, matching: find.byType(AppStatusDot)));
    expect(dot.kind, CheckStatusKind.covered);
    expect(dot.size, 8);
    final scroll = find.descendant(of: filters, matching: find.byType(SingleChildScrollView));
    expect(tester.widget<SingleChildScrollView>(scroll).scrollDirection, Axis.horizontal);
    expect(find.descendant(of: filters, matching: find.byType(Scrollbar)), findsNothing);
    await tester.drag(scroll, const Offset(-450, 0));
    await tester.pumpAndSettle();
    final review = find.descendant(
      of: filters,
      matching: find.bySemanticsLabel('Needs verification').hitTestable(),
    );
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(find.text('Three-policy example'), findsOneWidget);
    expect(find.text('Knee consultation'), findsNothing);
  });

  testWidgets('prescription filters find typed records on later pages', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        Brightness.light,
        ProviderScope(
          overrides: [prescriptionProvider.overrideWith(_MixedPrescriptions.new)],
          child: const PrescriptionListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final filters = find.byType(AppFilterChipRow<String>);
    expect(tester.widget<AppFilterChipRow<String>>(filters).selected, 'All');
    expect(find.text('2 saved'), findsOneWidget);
    expect(find.text('Uploaded treatment'), findsOneWidget);
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppFilterChipRow<String>>(filters).selected, 'Manual');
    expect(find.text('1 saved'), findsOneWidget);
    expect(find.text('Typed treatment'), findsOneWidget);
    expect(find.text('Uploaded treatment'), findsNothing);
    await tester.tap(find.text('Uploaded'));
    await tester.pumpAndSettle();
    expect(find.text('Uploaded treatment'), findsOneWidget);
    expect(find.text('Typed treatment'), findsNothing);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('2 saved'), findsOneWidget);
  });

  testWidgets('saved policy and prescription sheets open the matching original file', (tester) async {
    _phone(tester);
    final router = GoRouter(
      initialLocation: '/prescriptions',
      routes: [
        GoRoute(path: '/prescriptions', builder: (_, _) => const PrescriptionListScreen()),
        GoRoute(path: '/policies', builder: (_, _) => const PolicyListScreen()),
        GoRoute(
          path: '/view-pdf/:fileId',
          builder: (_, state) => Scaffold(
            body: Text('${state.pathParameters['fileId']} — ${state.uri.queryParameters['title']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policiesProvider.overrideWith(() => _Policies(hasFile: true)),
          prescriptionProvider.overrideWith(() => _Prescriptions(hasFile: true)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    for (final (list, file, title) in [
      ('/prescriptions', 'prescription-file', 'Knee consultation'),
      ('/policies', 'policy-file', 'Family Health'),
    ]) {
      router.go(list);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppDocumentRow));
      await tester.pumpAndSettle();
      final view = find.widgetWithText(AppButton, 'View document');
      expect(view.hitTestable(), findsOneWidget);
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(find.text('$file — $title'), findsOneWidget);
      expect(find.byType(AppSheet), findsNothing);
    }
  });

  testWidgets('edit name keeps email read-only and returns the saved name to Profile', (tester) async {
    _phone(tester);
    final account = _EditableAccount();
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const ProfileScreen(),
          routes: [GoRoute(path: 'edit-name', builder: (_, _) => const EditNameScreen())],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => account),
          themeProvider.overrideWith(() => _PreviewTheme(ThemeMode.light)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    final save = find.widgetWithText(AppButton, 'Save');
    expect(field, findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is SelectableText && widget.data == 'asha@example.test'),
      findsOneWidget,
    );
    expect(tester.widget<AppButton>(save).onPressed, isNull);
    await tester.enterText(field, 'Asha R.');
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(account.saved, ('Asha R.', 'asha@example.test'));
    expect(find.text('Asha R.'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('prescriptions, policies and History scroll and delete saved records in ${brightness.name}', (
      tester,
    ) async {
      _phone(tester);
      final policy = _PagedPolicies();
      final prescription = _PagedPrescriptions();
      final reports = _PagedChecks();
      for (final (screen, rowType, lastTitle, plural, removed) in [
        (const PolicyListScreen(), AppDocumentRow, 'Policy 12', 'policies', policy.removed),
        (
          const PrescriptionListScreen(),
          AppDocumentRow,
          'Treatment 12',
          'prescriptions',
          prescription.removed,
        ),
        (const AnalysesReportsScreen(), AppCheckRow, 'Check 12', 'checks', reports.removed),
      ]) {
        await tester.pumpWidget(
          _app(
            brightness,
            ProviderScope(
              overrides: [
                policiesProvider.overrideWith(() => policy),
                prescriptionProvider.overrideWith(() => prescription),
                analysisReportProvider.overrideWith(() => reports),
              ],
              child: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Previous'), findsNothing);
        expect(find.text('Next'), findsNothing);

        // Infinite scroll loads page 2 when nearing the bottom of the list.
        for (var i = 0; i < 6 && find.text(lastTitle).hitTestable().evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -600));
          await tester.pumpAndSettle();
        }
        expect(find.text(lastTitle), findsOneWidget);
        expect(find.byType(rowType), findsAtLeastNWidgets(1));

        // Long-press enters selection mode; Select all loads/selects every page.
        await tester.ensureVisible(find.text(lastTitle));
        await tester.pumpAndSettle();
        await tester.longPress(find.text(lastTitle));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
        await tester.tap(find.text('Select all'));
        await tester.pumpAndSettle();
        expect(find.text('12 selected'), findsOneWidget);

        await tester.tap(find.text('Delete 12 $plural'));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
        await tester.pumpAndSettle();
        expect(removed.toSet(), {for (var i = 1; i <= 12; i++) '$i'});
        expect(find.text(lastTitle), findsNothing);
      }
    });
  }
}

void _expectStackedLabels(WidgetTester tester, List<String> labels, {Finder? within}) {
  Rect? previous;
  for (final label in labels) {
    final text = find.text(label);
    final target = within == null ? text : find.descendant(of: within, matching: text);
    expect(target, findsOneWidget);
    final bounds = tester.getRect(target);
    if (previous != null) {
      expect(bounds.top, greaterThanOrEqualTo(previous.bottom));
      if (within == null) expect(bounds.left, previous.left);
    }
    previous = bounds;
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Brightness brightness, Widget content) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
    child: child!,
  ),
  home: content,
);

Future<void> _prepare(WidgetTester tester, Brightness brightness) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => precacheImage(
      AssetImage('assets/backgrounds/home_bg_${brightness.name}.png'),
      tester.element(find.byType(ListView).first),
    ),
  );
  await tester.pumpAndSettle();
}

AnalysisReportGroup _check(String id, String name, String date, String status) =>
    AnalysisReportGroup.fromJson({
      'groupId': id,
      'status': 'completed',
      'createdAt': date,
      'prescription': {'diagnosis': name, 'patientName': 'Asha Rao'},
      'policyReports': [
        {'policyName': 'Family Health', 'overallStatus': status},
      ],
    });

PaginationResponse<T> _results<T>(List<T> values) => PaginationResponse<T>(
  docs: values,
  totalDocs: values.length,
  limit: 10,
  totalPages: 1,
  page: 1,
  hasPrevPage: false,
  hasNextPage: false,
);

class _Checks extends AnalysisReportNotifier {
  _Checks([this.fixture]);

  final PaginationResponse<AnalysisReportGroup>? fixture;
  bool offline = false;

  @override
  Future<PaginationResponse<AnalysisReportGroup>> fetchPage(int page) async {
    if (offline) {
      throw DioException(
        requestOptions: RequestOptions(path: '/analysis/grouped'),
        type: DioExceptionType.connectionError,
      );
    }
    return fixture ?? _page;
  }
}

class _Policies extends PoliciesNotifier {
  _Policies({this.hasFile = false});

  final bool hasFile;

  @override
  Future<PaginationResponse<Policy>> fetchPage(int page) async => _results([
    Policy.fromJson({
      '_id': 'policy',
      if (hasFile) 'gridFsFileId': 'policy-file',
      'policyName': 'Family Health',
      'insuranceCompany': 'Example insurer',
      'policyNumber': 'PN-2468',
      'policyStartDate': '',
      'policyEndDate': '2001-02-03',
      'coverageAmount': 0,
      'extractedPolicyJson': {
        'continuity': {'policyStartDate': '1 Feb 2000', 'isRenewal': true, 'renewedWithoutBreak': false},
        'sumInsured': '₹5,00,000',
        'insuredMembers': [
          {'name': 'Asha Rao'},
          {'name': 'Raj Rao'},
        ],
      },
    }),
  ]);
}

class _MixedPrescriptions extends PrescriptionNotifier {
  @override
  Future<PaginationResponse<Prescription>> fetchPage(int page) async => PaginationResponse(
    docs: [
      Prescription.fromJson(
        page == 1
            ? {'_id': 'upload', 'diagnosis': 'Uploaded treatment', 'gridFsFileId': 'file'}
            : {'_id': 'typed', 'isManual': true, 'manualText': 'Typed treatment'},
      ),
    ],
    totalDocs: 2,
    limit: 1,
    totalPages: 2,
    page: page,
    hasPrevPage: page > 1,
    hasNextPage: page == 1,
  );
}

class _Prescriptions extends PrescriptionNotifier {
  _Prescriptions({this.hasFile = false});

  final bool hasFile;

  @override
  Future<PaginationResponse<Prescription>> fetchPage(int page) async => _results([
    Prescription.fromJson({
      '_id': 'prescription',
      if (hasFile) 'gridFsFileId': 'prescription-file',
      'diagnosis': 'Knee consultation',
      'doctorName': 'Dr. Sen',
      'patientName': 'Asha Rao',
      'visitDate': '',
      'extractedPrescriptionJson': {
        'treatmentDate': '2026-10-06',
        'medicines': [
          {'name': 'Naproxen'},
        ],
        'medicalTests': ['X-ray'],
      },
    }),
  ]);
}

PaginationResponse<T> _numberedPage<T>(int page, List<String> removed, T Function(String) make) {
  final ids = [
    for (var i = 1; i <= 12; i++)
      if (!removed.contains('$i')) '$i',
  ];
  return PaginationResponse(
    docs: ids.skip((page - 1) * 10).take(10).map(make).toList(),
    totalDocs: ids.length,
    limit: 10,
    totalPages: (ids.length / 10).ceil(),
    page: page,
    hasPrevPage: page > 1,
    hasNextPage: page * 10 < ids.length,
  );
}

class _PagedPolicies extends PoliciesNotifier {
  final removed = <String>[];

  @override
  Future<PaginationResponse<Policy>> fetchPage(int page) async =>
      _numberedPage(page, removed, (id) => Policy.fromJson({'_id': id, 'policyName': 'Policy $id'}));

  @override
  Future<int> deletePolicies(List<String> ids) async {
    removed.addAll(ids);
    await refreshPage();
    return ids.length;
  }
}

class _PagedPrescriptions extends PrescriptionNotifier {
  final removed = <String>[];

  @override
  Future<PaginationResponse<Prescription>> fetchPage(int page) async =>
      _numberedPage(page, removed, (id) => Prescription.fromJson({'_id': id, 'diagnosis': 'Treatment $id'}));

  @override
  Future<int> deletePrescriptions(List<String> ids) async {
    removed.addAll(ids);
    await refreshPage();
    return ids.length;
  }
}

class _PagedChecks extends AnalysisReportNotifier {
  final removed = <String>[];

  @override
  Future<PaginationResponse<AnalysisReportGroup>> fetchPage(int page) async =>
      _numberedPage(page, removed, (id) => _check(id, 'Check $id', '2026-10-01', 'Covered'));

  @override
  Future<int> deleteReports(List<String> ids) async {
    removed.addAll(ids);
    await refreshPage();
    return ids.length;
  }
}

class _Account extends AuthNotifier {
  @override
  Future<User?> build() async =>
      User.fromJson({'id': 'person', 'name': 'Asha Rao', 'email': 'asha@example.test'});
}

class _EditableAccount extends _Account {
  (String, String)? saved;

  @override
  Future<void> updateProfile(String name, String email) async {
    saved = (name, email);
    state = AsyncData(User.fromJson({'id': 'person', 'name': name, 'email': email}));
  }
}

class _ProfileNotifications extends CheckNotifications {
  final _setting = ValueNotifier(true);

  @override
  ValueListenable<bool> get enabled => _setting;

  @override
  Future<void> setEnabled(bool value) async => _setting.value = value;

  @override
  void dispose() {
    _setting.dispose();
    super.dispose();
  }
}

class _PreviewTheme extends ThemeNotifier {
  _PreviewTheme(this.chosen);
  ThemeMode chosen;

  @override
  ThemeMode build() => chosen;

  @override
  Future<void> selectTheme(ThemeMode mode) async {
    chosen = mode;
    state = mode;
  }
}
