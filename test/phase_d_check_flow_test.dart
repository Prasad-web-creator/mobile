import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:claimsupport/core/config/app_config_provider.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/home_background.dart';
import 'package:claimsupport/core/routing/app_back_dispatcher.dart';
import 'package:claimsupport/features/analysis/data/repositories/new_check_repository.dart';
import 'package:claimsupport/features/analysis/presentation/screens/check_processing_screen.dart';
import 'package:claimsupport/features/analysis/presentation/widgets/analysis_exit_guard.dart';
import 'package:claimsupport/features/analysis/presentation/screens/new_check_screen.dart';
import 'package:claimsupport/features/checks/presentation/check_completion_monitor.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:claimsupport/features/prescriptions/presentation/screens/typed_prescription_screen.dart';

DateTime _savedToday(int minute) {
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day, 15, minute);
}

final _treatment = Prescription.fromJson({
  'id': 'fixture-rx',
  'diagnosis': 'Example treatment',
  'patientName': 'Sample person with a long name',
  'visitDate': '2025-06-01',
  'createdAt': _savedToday(55),
  'gridFsFileId': 'fixture-file',
  'isManual': false,
  'extractedPrescriptionText': 'Text extracted from the uploaded prescription.',
});

final _policies = [
  Policy.fromJson({
    'id': 'fixture-policy',
    'policyName': 'Example Health Plan',
    'insuranceCompany': 'Example insurer',
    'status': 'Active',
  }),
  Policy.fromJson({'id': 'fixture-expired', 'policyName': 'Previous Health Plan', 'status': 'Expired'}),
];

class _FakeRepository implements NewCheckRepository {
  List<String>? startedWith;
  String jobStatus = 'extracting_documents';
  bool offline = false;
  bool cancelFails = false;
  Future<void>? startGate;
  final cancelledJobs = <String>[];
  final typed = <String>[];
  int createdJobs = 0;

  @override
  Future<String> createJob(String requestId) async {
    createdJobs++;
    return 'fixture-job';
  }

  @override
  Future<Prescription> saveTypedPrescription(String text) async {
    typed.add(text);
    return Prescription.fromJson({
      'id': 'typed-${typed.length}',
      'isManual': true,
      'extractedPrescriptionText': text,
      'createdAt': _savedToday(35),
    });
  }

  @override
  Future<Map<String, dynamic>> readJob(String jobId) async {
    if (offline) throw StateError('Fixture offline');
    return {
      'id': jobId,
      'status': jobStatus,
      'policyIds': ['fixture-policy'],
    };
  }

  @override
  Future<void> start(String jobId, String treatment, List<String> policies) async {
    startedWith = [jobId, treatment, ...policies];
    await startGate;
  }

  @override
  Future<void> cancelJob(String jobId) async {
    cancelledJobs.add(jobId);
    if (cancelFails) throw StateError('Fixture cancellation failed');
    jobStatus = 'cancelled';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMonitor extends CheckCompletionMonitor {
  String? tracked;
  String? viewed;
  String? acknowledged;

  @override
  int build() => 0;

  @override
  void track(String jobId) => tracked = jobId;

  @override
  void setProcessingView(String jobId, bool visible) => viewed = visible ? jobId : null;

  @override
  void acknowledge(String jobId) => acknowledged = jobId;
}

Future<GoRouter> _app(
  WidgetTester tester, {
  required _FakeRepository repository,
  required _FakeMonitor monitor,
  required Brightness brightness,
  bool empty = false,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final root = BackRouteObserver();
  final shell = BackRouteObserver();
  final router = GoRouter(
    initialLocation: '/dashboard',
    observers: [root],
    routes: [
      ShellRoute(
        observers: [shell],
        notifyRootObserver: false,
        builder: (_, _, child) => child,
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const Scaffold(body: Text('Dashboard')),
          ),
          GoRoute(path: '/check/new', onExit: confirmAnalysisRouteExit, builder: (_, _) => const NewCheckScreen()),
          GoRoute(path: '/prescriptions/type', builder: (_, _) => const TypedPrescriptionScreen()),
          GoRoute(
            path: '/check/processing/:jobId',
            onExit: confirmAnalysisRouteExit,
            builder: (_, state) => CheckProcessingScreen(jobId: state.pathParameters['jobId']!),
          ),
          GoRoute(
            path: '/reports',
            builder: (_, _) => const Scaffold(body: Text('History')),
          ),
          GoRoute(
            path: '/checks/:id',
            builder: (_, _) => const Scaffold(body: Text('Check details')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith((_) async => AppRuntimeConfig.defaults),
        checkTreatmentsProvider.overrideWith((_) async => empty ? [] : [_treatment]),
        checkPoliciesProvider.overrideWith((_) async => empty ? [] : _policies),
        newCheckRepositoryProvider.overrideWithValue(repository),
        checkCompletionMonitorProvider.overrideWith(() => monitor),
      ],
      child: Consumer(
        builder: (_, ref, child) {
          ref.watch(checkCompletionMonitorProvider.notifier);
          return child!;
        },
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: RouterConfig<RouteMatchList>(
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
            backButtonDispatcher: AppBackDispatcher(router, root: root, shell: shell, homePath: '/dashboard'),
          ),
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.3),
              padding: const EdgeInsets.only(top: 26, bottom: 12),
            ),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _button(String label) => find.widgetWithText(AppButton, label);
Finder _row(String label) => find.byWidgetPredicate((widget) => widget is AppDocumentRow && widget.title == label);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final (family, files) in <(String, List<String>)>[
      ('Geist', ['Geist-Regular', 'Geist-Medium', 'Geist-SemiBold', 'Geist-Bold']),
      ('PhosphorRegular', ['phosphor/Phosphor']),
    ]) {
      final font = FontLoader(family);
      for (final name in files) {
        font.addFont(rootBundle.load('assets/fonts/$name.ttf'));
      }
      await font.load();
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('new check keeps selection and handles expiry in ${brightness.name}', (tester) async {
      final repo = _FakeRepository();
      final monitor = _FakeMonitor();
      final router = await _app(tester, repository: repo, monitor: monitor, brightness: brightness);
      router.push('/check/new');
      await tester.pumpAndSettle();
      expect(find.text('Select prescription'), findsOneWidget);
      expect(tester.widget<AppButton>(_button('Continue')).onPressed, isNull);
      expect(tester.getTopLeft(_row('Add new')).dy, lessThan(tester.getTopLeft(_row('Example treatment')).dy));
      expect(find.byType(HomeBackground), findsNothing);
      expect(find.text('Today   03 : 55 PM').hitTestable(), findsOneWidget);
      await tester.pump();
      await tester.tap(_row('Example treatment'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppDocumentRow>(_row('Example treatment')).selected, isTrue);
      await tester.tap(_button('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Select policies'), findsOneWidget);
      expect(tester.widget<AppDocumentRow>(_row('Previous Health Plan')).onTap, isNull);
      expect(tester.widget<AppDocumentRow>(_row('Example Health Plan')).selected, isFalse);
      expect(tester.widget<AppButton>(_button('Check 0 policies')).onPressed, isNull);
      expect(tester.getTopLeft(_row('Add new')).dy, lessThan(tester.getTopLeft(_row('Example Health Plan')).dy));

      await tester.tap(_row('Example Health Plan'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppButton>(_button('Check 1 policy')).onPressed, isNotNull);
      await tester.tap(find.bySemanticsLabel('Back to treatment'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppDocumentRow>(_row('Example treatment')).selected, isTrue);
      await tester.tap(_button('Continue'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppDocumentRow>(_row('Example Health Plan')).selected, isTrue);
      await tester.tap(_row('Example Health Plan'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppDocumentRow>(_row('Example Health Plan')).selected, isFalse);
      expect(tester.widget<AppButton>(_button('Check 0 policies')).onPressed, isNull);
      await tester.tap(_row('Example Health Plan'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Check 1 policy'));
      await tester.pumpAndSettle();
      expect(find.text('Before we begin'), findsNothing);

      expect(repo.startedWith, ['fixture-job', 'fixture-rx', 'fixture-policy']);
      expect(monitor.tracked, 'fixture-job');
      expect(monitor.viewed, 'fixture-job');
      expect(find.text('Reading your documents…'), findsOneWidget);

      repo.jobStatus = 'analyzing';
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Checking your policies…'), findsOneWidget);

      repo.offline = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't refresh. Your check can keep running."), findsOneWidget);
      repo.offline = false;
      repo.jobStatus = 'failed';
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't finish this check"), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
      expect(monitor.viewed, isNull);
    });

    testWidgets('empty check always offers an inline add sheet in ${brightness.name}', (tester) async {
      final router = await _app(
        tester,
        repository: _FakeRepository(),
        monitor: _FakeMonitor(),
        brightness: brightness,
        empty: true,
      );
      router.push('/check/new');
      await tester.pumpAndSettle();
      expect(find.text('Select prescription'), findsOneWidget);
      await tester.tap(_row('Add new'));
      await tester.pumpAndSettle();
      expect(_row('Scan'), findsOneWidget);
      expect(_row('Upload file'), findsOneWidget);
      expect(_row('Photos'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_row('Add new'), findsOneWidget);
    });
  }

  testWidgets('a visible check opens details when the durable job finishes', (tester) async {
    final repo = _FakeRepository();
    final monitor = _FakeMonitor();
    final router = await _app(tester, repository: repo, monitor: monitor, brightness: Brightness.light);
    router.push('/check/processing/fixture-job');
    await tester.pumpAndSettle();
    expect(find.text('Reading your documents…'), findsOneWidget);
    expect(monitor.tracked, 'fixture-job');

    repo.jobStatus = 'completed';
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Check details'), findsOneWidget);
    expect(monitor.acknowledged, 'fixture-job');
    expect(monitor.viewed, isNull);
  });

  testWidgets('back and tab navigation confirm cancellation of a running check', (tester) async {
    final repo = _FakeRepository()..jobStatus = 'analyzing';
    final monitor = _FakeMonitor();
    final router = await _app(tester, repository: repo, monitor: monitor, brightness: Brightness.dark);
    router.push('/check/processing/fixture-job');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Stop the analysis?'), findsOneWidget);
    await tester.tap(find.text('Keep analyzing'));
    await tester.pumpAndSettle();
    expect(repo.cancelledJobs, isEmpty);
    expect(find.byType(CheckProcessingScreen), findsOneWidget);

    router.go('/reports');
    await tester.pumpAndSettle();
    expect(find.text('Stop the analysis?'), findsOneWidget);
    await tester.tap(find.text('Stop analysis'));
    await tester.pumpAndSettle();
    expect(repo.cancelledJobs, ['fixture-job']);
    expect(monitor.acknowledged, 'fixture-job');
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('returning from the background prompts and a failed stop stays on the check', (tester) async {
    final repo = _FakeRepository()..cancelFails = true;
    final router = await _app(tester, repository: repo, monitor: _FakeMonitor(), brightness: Brightness.light);
    router.push('/check/processing/fixture-job');
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Stop the analysis?'), findsOneWidget);
    await tester.tap(find.text('Stop analysis'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't confirm the analysis stopped. Try again."), findsOneWidget);
    expect(find.byType(CheckProcessingScreen), findsOneWidget);
    expect(repo.cancelledJobs, ['fixture-job']);
  });

  testWidgets('Android back goes to Home and a second back closes the app', (tester) async {
    var closes = 0;
    final platform = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    platform.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') closes++;
      return null;
    });
    addTearDown(() => platform.setMockMethodCallHandler(SystemChannels.platform, null));
    final router = await _app(
      tester,
      repository: _FakeRepository(),
      monitor: _FakeMonitor(),
      brightness: Brightness.light,
    );
    router.go('/reports');
    await tester.pumpAndSettle();
    router.push('/checks/sample');
    await tester.pumpAndSettle();
    expect(find.text('Check details'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(closes, 0);
    await tester.binding.handlePopRoute();
    expect(closes, 1);
  });

  testWidgets('Android back can stop a check while the start request is pending', (tester) async {
    final start = Completer<void>();
    final repo = _FakeRepository()..startGate = start.future;
    final monitor = _FakeMonitor();
    final router = await _app(tester, repository: repo, monitor: monitor, brightness: Brightness.light);
    router.push('/check/new');
    await tester.pumpAndSettle();
    await tester.tap(_row('Example treatment'));
    await tester.pumpAndSettle();
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(_row('Example Health Plan'));
    await tester.pumpAndSettle();
    await tester.tap(_button('Check 1 policy'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(repo.startedWith, isNotNull);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('Stop the analysis?'), findsOneWidget);
    await tester.tap(find.text('Stop analysis'));
    start.complete();
    await tester.pumpAndSettle();
    expect(repo.cancelledJobs, ['fixture-job']);
    expect(monitor.tracked, isNull);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('typed prescriptions save directly in ${brightness.name}', (tester) async {
      final repo = _FakeRepository();
      final router = await _app(tester, repository: repo, monitor: _FakeMonitor(), brightness: brightness);
      router.push('/check/new');
      await tester.pumpAndSettle();
      expect(find.textContaining('For Sample person'), findsOneWidget);
      expect(find.textContaining('Typed by you'), findsNothing);
      for (final treatment in ['Fever', 'Kidney stone']) {
        await tester.tap(_row('Add new'));
        await tester.pumpAndSettle();
        await tester.tap(_row('Type it in'));
        await tester.pumpAndSettle();
        expect(tester.widget<AppButton>(_button('Save prescription')).onPressed, isNull);
        expect(find.text('Examples'), findsNothing);
        expect(find.byType(ActionChip), findsNothing);
        await tester.enterText(find.byType(TextField), treatment);
        await tester.pumpAndSettle();
        await tester.tap(_button('Save prescription'));
        await tester.pumpAndSettle();
        expect(find.text('Before we begin'), findsNothing);
        expect(tester.widget<AppDocumentRow>(_row(treatment)).selected, isTrue);
        expect(find.text('Typed by you'), findsWidgets);
        expect(
          find.descendant(of: _row(treatment), matching: find.text('Today   03 : 35 PM')).hitTestable(),
          findsOneWidget,
        );
      }
      expect(repo.typed, ['Fever', 'Kidney stone']);
      expect(repo.createdJobs, 0);
    });
  }

  test('policy numbers are normalized without merging missing identifiers', () {
    expect(NewCheckRepository.normalizePolicyNumber(' abc - 123 / d '), 'ABC123D');
    expect(NewCheckRepository.normalizePolicyNumber('N/A'), isEmpty);
    expect(NewCheckRepository.normalizePolicyNumber(null), isEmpty);
  });
}
