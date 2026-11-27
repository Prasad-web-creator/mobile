import 'package:claimsupport/features/analysis/data/repositories/new_check_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/android_navigation_background.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/floating_nav_bar.dart';
import 'package:claimsupport/core/design/widgets/home_background.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/core/routing/app_router.dart';
import 'package:claimsupport/core/services/admob_service.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/dashboard/data/models/dashboard_stats.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';
import 'package:claimsupport/features/home/presentation/screens/home_screen.dart';
import 'package:claimsupport/features/home/presentation/widgets/home_entrance.dart';

const _amount = '₹1,24,000';

ThemeData _theme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  brightness: brightness,
  extensions: [
    brightness == Brightness.dark ? AppColors.dark : AppColors.light,
    brightness == Brightness.dark ? AppIllustrationColors.dark : AppIllustrationColors.light,
  ],
);

Widget _app(Widget home, {ThemeMode mode = ThemeMode.light, bool reduceMotion = false}) => MaterialApp(
  theme: _theme(Brightness.light),
  darkTheme: _theme(Brightness.dark),
  themeMode: mode,
  debugShowCheckedModeBanner: false,
  builder: (context, child) => _scaledPhone(context, child!, reduceMotion: reduceMotion),
  home: home,
);

Widget _scaledPhone(BuildContext context, Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQuery.of(context).copyWith(
    padding: const EdgeInsets.only(top: 30, bottom: 20),
    viewPadding: const EdgeInsets.only(top: 30, bottom: 20),
    textScaler: const TextScaler.linear(1.3),
    disableAnimations: reduceMotion,
  ),
  child: child,
);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 780);
  addTearDown(tester.view.reset);
}

Widget _rows() => ListView.builder(
  padding: const EdgeInsets.fromLTRB(DsSpace.screenPadding, DsSpace.s8, DsSpace.screenPadding, DsSpace.s64),
  itemCount: 22,
  itemBuilder: (context, index) => Padding(
    padding: const EdgeInsets.only(bottom: DsSpace.s12),
    child: DecoratedBox(
      decoration: ShapeDecoration(
        shape: DsShape.shape(DsShape.radiusXl),
        color: context.colors.surfaceCardSubtle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.cardPadding),
        child: Text(
          index == 0 ? _amount : 'Example item ${index + 1}',
          style: (index == 0 ? AppTextStyles.numberCount : AppTextStyles.bodyStrong).copyWith(
            color: context.colors.textPrimary,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = <String, List<String>>{
      'Geist': ['Geist-Regular', 'Geist-Medium', 'Geist-SemiBold', 'Geist-Bold'],
      'PhosphorRegular': ['phosphor/Phosphor'],
      'PhosphorFill': ['phosphor/Phosphor-Fill'],
    };
    for (final entry in fonts.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$name.ttf'));
      }
      await loader.load();
    }
  });

  testWidgets('floating navigation keeps a 16 pixel gap above the system inset', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.dark),
        home: RootShell(
          body: const SizedBox.shrink(),
          navigation: FloatingNavBar(currentIndex: 0, onTabSelected: (_) {}, onNewCheck: () {}),
        ),
      ),
    );
    final newCheck = find.bySemanticsLabel('New check');

    for (final inset in [0.0, 24.0, 34.0, 48.0]) {
      tester.view.viewPadding = FakeViewPadding(bottom: inset);
      tester.view.padding = FakeViewPadding(bottom: inset);
      await tester.pump();
      expect(tester.getBottomRight(newCheck).dy, 780 - inset - 16);
    }

    tester.view.padding = const FakeViewPadding();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(tester.getBottomRight(newCheck).dy, 780 - 48 - 16);

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.ancestor(of: newCheck, matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>)).first,
    );
    expect(overlay.value.systemNavigationBarColor, Colors.transparent);
    expect(overlay.value.systemNavigationBarDividerColor, Colors.transparent);
    expect(overlay.value.systemNavigationBarIconBrightness, Brightness.light);
    expect(overlay.value.systemNavigationBarContrastEnforced, isFalse);
  });

  testWidgets('Android system navigation paints an opaque inset in both themes', (tester) async {
    _phone(tester);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    final bodyKey = GlobalKey();
    for (final mode in Brightness.values) {
      final colors = mode == Brightness.dark ? AppColors.dark : AppColors.light;
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(mode),
          home: AndroidNavigationBackground(child: SizedBox.expand(key: bodyKey)),
        ),
      );
      await tester.pumpAndSettle();
      final region = find.descendant(
        of: find.byType(AndroidNavigationBackground),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(tester.getRect(region), Rect.fromLTWH(0, 732, 360, 48));
      final background = find.descendant(of: region, matching: find.byType(ColoredBox));
      expect(tester.widget<ColoredBox>(background).color, colors.backgroundPage);
      expect(
        tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(region).value.systemNavigationBarIconBrightness,
        mode == Brightness.dark ? Brightness.light : Brightness.dark,
      );
      final body = bodyKey.currentContext;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(region, findsNothing);
      expect(bodyKey.currentContext, same(body));
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump();
    }
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('root uses a plain page and moves navigation (${mode.name})', (tester) async {
      _phone(tester);
      int? tab;
      var checksStarted = 0;
      await tester.pumpWidget(
        _app(
          RootShell(
            title: 'History',
            navigation: FloatingNavBar(
              currentIndex: 1,
              onTabSelected: (index) => tab = index,
              onNewCheck: () => checksStarted++,
            ),
            body: _rows(),
          ),
          mode: mode,
          reduceMotion: mode == ThemeMode.dark,
        ),
      );
      await _prepare(tester, mode);

      expect(find.byType(HomeBackground), findsNothing);
      await tester.tap(find.bySemanticsLabel('Home'));
      await tester.tap(find.bySemanticsLabel('New check'));
      expect(tab, 0);
      expect(checksStarted, 1);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -130));
      await tester.pumpAndSettle();
      final navSemantics = find.ancestor(
        of: find.bySemanticsLabel('New check'),
        matching: find.byType(ExcludeSemantics),
      );
      expect(tester.widget<ExcludeSemantics>(navSemantics.first).excluding, isTrue);
      expect(find.bySemanticsLabel('New check').hitTestable(), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 50));
      await tester.pumpAndSettle();
      expect(tester.widget<ExcludeSemantics>(navSemantics.first).excluding, isFalse);
      expect(find.bySemanticsLabel('New check').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pushed collapses the title and keeps its 44pt back control (${mode.name})', (tester) async {
      _phone(tester);
      var back = 0;
      await tester.pumpWidget(
        _app(
          PushedShell(title: 'Coverage Summary', onBack: () => back++, body: _rows()),
          mode: mode,
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.bySemanticsLabel('Back');
      expect(tester.getSize(backButton), const Size.square(44));
      expect(tester.getTopLeft(backButton), const Offset(20, 38));
      expect(find.byType(FloatingNavBar), findsNothing);
      expect(find.byType(HomeBackground), findsNothing);
      final compactTitle = find.descendant(
        of: find.byType(AnimatedOpacity),
        matching: find.text('Coverage Summary'),
      );
      final compactOpacity = find.ancestor(of: compactTitle, matching: find.byType(AnimatedOpacity));
      expect(tester.widget<AnimatedOpacity>(compactOpacity).opacity, 0);
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(compactOpacity).opacity, 1);
      expect(find.byType(HomeBackground), findsNothing);
      await tester.tap(backButton);
      expect(back, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('flow keeps the CTA and background in place (${mode.name})', (tester) async {
      _phone(tester);
      var closed = 0;
      var tapped = 0;
      await tester.pumpWidget(
        _app(
          FlowShell(
            title: 'Add Prescription',
            step: 2,
            stepCount: 3,
            onClose: () => closed++,
            bottomAction: AppButton(label: 'Process Manual Prescription', onPressed: () => tapped++),
            body: _rows(),
          ),
          mode: mode,
        ),
      );
      await tester.pumpAndSettle();
      final button = find.bySemanticsLabel('Process Manual Prescription');
      final cta = tester.getRect(button);
      expect(find.byType(HomeBackground), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(tester.getRect(button), cta);
      expect(find.byType(HomeBackground), findsNothing);
      expect(find.byType(FloatingNavBar), findsNothing);
      await tester.tap(button);
      await tester.tap(find.bySemanticsLabel('Close'));
      expect(tapped, 1);
      expect(closed, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sheet shows a themed continuous surface (${mode.name})', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => RootShell(
              title: 'History',
              navigation: const SizedBox.shrink(),
              body: Center(
                child: AppButton(
                  label: 'Open details',
                  onPressed: () => AppSheet.show<void>(
                    context: context,
                    title: 'Account Information',
                    bodyBuilder: (context) => Text(
                      'Account details',
                      style: AppTextStyles.bodyStrong.copyWith(color: context.colors.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          mode: mode,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Open details'));
      await tester.pumpAndSettle();
      final sheet = tester.widget<Material>(
        find.descendant(of: find.byType(AppSheet), matching: find.byType(Material)),
      );
      expect(sheet.shape, isA<RoundedSuperellipseBorder>());
      expect(sheet.color, (mode == ThemeMode.dark ? AppColors.dark : AppColors.light).surfaceCardRaised);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('theme switch updates the shell surface', (tester) async {
    _phone(tester);
    Widget shell() => RootShell(
      title: 'Home',
      useHomeBackgroundColor: true,
      navigation: const SizedBox.shrink(),
      body: Builder(
        builder: (context) =>
            ColoredBox(key: const ValueKey('token surface'), color: context.illustration.paperWarmTop),
      ),
    );
    await tester.pumpWidget(_app(shell()));
    await _prepare(tester, ThemeMode.light);
    expect(
      tester.widget<ColoredBox>(find.byKey(const ValueKey('token surface'))).color,
      AppIllustrationColors.light.paperWarmTop,
    );
    await tester.pumpWidget(_app(shell(), mode: ThemeMode.dark));
    await _prepare(tester, ThemeMode.dark);
    expect(
      tester.widget<ColoredBox>(find.byKey(const ValueKey('token surface'))).color,
      AppIllustrationColors.dark.paperWarmTop,
    );
    expect(find.byType(HomeBackground), findsNothing);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, AppColors.dark.backgroundHome);
  });

  testWidgets('Home artwork is a pre-blurred image at the design height', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const HomeBackground(), mode: ThemeMode.dark));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, endsWith('home_bg_dark.png'));
    expect(image.height, 460);
    expect(image.fit, BoxFit.fill);
    expect(image.filterQuality, FilterQuality.high);
  });

  testWidgets('Home explains a wrapped server connection failure', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authProvider.overrideWith(_SignedInTestUser.new),
          homeChecksProvider.overrideWith((ref) async {
            throw AppException(
              message: 'Unknown error',
              originalException: DioException(
                requestOptions: RequestOptions(path: '/analysis/grouped'),
                type: DioExceptionType.connectionError,
              ),
            );
          }),
          dashboardStatsProvider.overrideWith(_EmptyDashboard.new),
        ],
        child: _app(const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Can’t connect to Policy Pal'), findsOneWidget);
    expect(find.textContaining('this phone is on the same network'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Unknown error'), findsNothing);
  });

  testWidgets('app routes switch Home and History and open the two-step check flow', (tester) async {
    _phone(tester);
    final adsEnabled = AdMobConfig.isEnabled;
    AdMobConfig.setEnabled(false);
    addTearDown(() => AdMobConfig.setEnabled(adsEnabled));
    final router = AppRouter.router;
    final themeMode = ValueNotifier(ThemeMode.light);
    addTearDown(themeMode.dispose);
    router.go('/dashboard');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_SignedInTestUser.new),
          homeChecksProvider.overrideWith((ref) async => []),
          dashboardStatsProvider.overrideWith(_EmptyDashboard.new),
          analysisReportProvider.overrideWith(_EmptyHistory.new),
          checkTreatmentsProvider.overrideWith((ref) async => []),
        ],
        child: ValueListenableBuilder(
          valueListenable: themeMode,
          builder: (context, mode, _) => MaterialApp.router(
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            themeMode: mode,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => _scaledPhone(context, child!),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Know your cover before the bill'), findsOneWidget);
    final homeList = find.byType(ListView).first;
    expect(tester.widget<ListView>(homeList).padding!.resolve(TextDirection.ltr).bottom, 128);
    await _prepare(tester, ThemeMode.light);
    themeMode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    await _prepare(tester, ThemeMode.dark);
    final navWidget = tester.widget<FloatingNavBar>(find.byType(FloatingNavBar));
    final entrance = tester.widget<HomeEntrance>(find.byType(HomeEntrance)).progress;
    expect(entrance.value, 1);
    void expectPlainNavLabels() {
      for (final label in ['Home', 'History', 'New check']) {
        final text = find.descendant(of: find.byType(FloatingNavBar), matching: find.text(label));
        final richText = tester.widget<RichText>(find.descendant(of: text, matching: find.byType(RichText)));
        expect(richText.text.style?.decoration, TextDecoration.none, reason: label);
      }
    }

    expectPlainNavLabels();
    await tester.tap(find.bySemanticsLabel('History'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/reports');
    expect(find.text('No checks yet'), findsOneWidget);
    themeMode.value = ThemeMode.light;
    await tester.pumpAndSettle();
    expectPlainNavLabels();
    // Persistent nav: same FloatingNavBar widget stays mounted in the shell.
    expect(tester.widget<FloatingNavBar>(find.byType(FloatingNavBar)), isNotNull);
    final historyList = find.byType(ListView).last;
    expect(tester.widget<ListView>(historyList).padding!.resolve(TextDirection.ltr).bottom, greaterThan(80));
    await tester.tap(find.bySemanticsLabel('New check'));
    await tester.pumpAndSettle();
    expect(find.byType(FlowShell), findsOneWidget);
    expect(find.text('Select prescription'), findsOneWidget);
    expect(find.byType(FloatingNavBar).hitTestable(), findsNothing);
    await tester.tap(find.bySemanticsLabel('Close').hitTestable());
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/reports');
    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pump();
    expect(tester.widget<HomeEntrance>(find.byType(HomeEntrance)).progress, same(entrance));
    expect(entrance.value, 1);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    expect(find.byType(RootShell).hitTestable(), findsOneWidget);
    expect(navWidget, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Geist count style uses tabular digits', (tester) async {
    double width(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: AppTextStyles.numberCount),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    expect(AppTextStyles.numberCount.fontFamily, 'Geist');
    expect(width('₹1,11,111'), closeTo(width('₹8,88,888'), 0.01));
  });
}

Future<void> _prepare(WidgetTester tester, ThemeMode mode) async {
  final artwork = find.byType(HomeBackground);
  if (artwork.evaluate().isNotEmpty) {
    await tester.runAsync(
      () => precacheImage(AssetImage('assets/backgrounds/home_bg_${mode.name}.png'), tester.element(artwork)),
    );
  }
  await tester.pumpAndSettle();
}

class _SignedInTestUser extends AuthNotifier {
  @override
  Future<User?> build() async => null;
}

class _EmptyDashboard extends DashboardStatsNotifier {
  @override
  Future<DashboardStats> build() async =>
      DashboardStats(totalPolicies: 0, totalPrescriptions: 0);
}

class _EmptyHistory extends AnalysisReportNotifier {
  @override
  Future<PaginationResponse<AnalysisReportGroup>> build() async => PaginationResponse(
    docs: [],
    totalDocs: 0,
    limit: 10,
    totalPages: 1,
    page: 1,
    hasPrevPage: false,
    hasNextPage: false,
  );
}
