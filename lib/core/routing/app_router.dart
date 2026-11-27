import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:claimsupport/debug/component_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/design/widgets/app_design_surface.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/routing/app_back_dispatcher.dart';
import 'package:claimsupport/core/routing/app_shell.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/authentication/presentation/screens/splash_screen.dart';
import 'package:claimsupport/features/authentication/presentation/screens/login_screen.dart';
import 'package:claimsupport/features/authentication/presentation/screens/register_screen.dart';
import 'package:claimsupport/features/home/presentation/screens/home_screen.dart';
import 'package:claimsupport/features/home/presentation/widgets/home_entrance.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/features/documents/presentation/screens/documents_screen.dart';
import 'package:claimsupport/features/documents/presentation/saved_list_actions.dart';
import 'package:claimsupport/features/prescriptions/presentation/screens/typed_prescription_screen.dart';
import 'package:claimsupport/features/upload/presentation/screens/upload_prescription_screen.dart';
import 'package:claimsupport/features/upload/presentation/screens/upload_policy_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/consent_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/analysis_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/multi_analysis_screen.dart';
import 'package:claimsupport/features/summary/presentation/screens/summary_screen.dart';
import 'package:claimsupport/features/analyses_reports/presentation/screens/analyses_reports_screen.dart';
import 'package:claimsupport/features/profile/presentation/screens/profile_screen.dart';
import 'package:claimsupport/features/profile/presentation/screens/edit_name_screen.dart';
import 'package:claimsupport/features/pdf_viewer/presentation/screens/pdf_viewer_screen.dart';

import 'package:claimsupport/features/profile/presentation/screens/settings_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/new_check_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/check_processing_screen.dart';
import 'package:claimsupport/features/analysis/presentation/widgets/analysis_exit_guard.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/checks/presentation/check_completion_monitor.dart';
import 'package:claimsupport/features/summary/presentation/screens/check_details_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final GlobalKey<NavigatorState> _historyNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'history');

class AppRouter {
  static String _initialLocation = '/splash';

  static bool get usesNativeSplash => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Resolve the Android launcher destination before the router draws its first frame.
  static Future<void> prepareStartup() async {
    if (usesNativeSplash) _initialLocation = await SplashScreen.resolveDestination();
  }

  static const _sampleCoverageResponse = String.fromEnvironment('POLICY_PAL_SAMPLE_COVERAGE_RESPONSE');
  static final _rootBackRoutes = BackRouteObserver();
  static final _shellBackRoutes = BackRouteObserver();

  static final config = RouterConfig<RouteMatchList>(
    routeInformationProvider: router.routeInformationProvider,
    routeInformationParser: router.routeInformationParser,
    routerDelegate: router.routerDelegate,
    backButtonDispatcher: AppBackDispatcher(
      router,
      root: _rootBackRoutes,
      shell: _shellBackRoutes,
      homePath: AppRootNavigation.homePath,
      dismissSelection: (path) {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return false;
        final selection = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(activeListSelectionProvider).value;
        if (selection == null || selection.path != path) return false;
        selection.close();
        return true;
      },
    ),
  );

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [_rootBackRoutes],
    initialLocation: _initialLocation,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/splash'),
      GoRoute(
        path: '/splash',
        redirect: (context, state) => usesNativeSplash ? SplashScreen.resolveDestination() : null,
        builder: (context, state) => const SplashScreen(),
      ),
      if (kDebugMode)
        GoRoute(path: '/debug/components', builder: (context, state) => const ComponentGallery()),
      if (kDebugMode && _sampleCoverageResponse.isNotEmpty)
        GoRoute(
          path: '/debug/sample-coverage',
          builder: (context, state) => AppDesignSurface(
            child: SummaryScreen(reportSnapshot: jsonDecode(_sampleCoverageResponse) as Map<String, dynamic>),
          ),
        ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      // Outer ShellRoute: wraps flow/non-tab screens with CheckCompletionBridge.
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        observers: [_shellBackRoutes],
        notifyRootObserver: false,
        builder: (context, state, child) => AppDesignSurface(child: CheckCompletionBridge(child: child)),
        routes: [
          GoRoute(
            path: '/check/new',
            onExit: confirmAnalysisRouteExit,
            builder: (context, state) => NewCheckScreen(
              addPrescriptionOnly: state.uri.queryParameters['add'] == 'prescription',
              initialPrescriptionId: state.uri.queryParameters['prescription'],
              initialPolicyIds: state.extra is AnalysisReportGroup
                  ? (state.extra as AnalysisReportGroup).policyReports.map((row) => row.policyId).toSet()
                  : const {},
            ),
          ),
          GoRoute(path: '/prescriptions/type', builder: (_, _) => const TypedPrescriptionScreen()),
          GoRoute(
            path: '/check/processing/:jobId',
            onExit: confirmAnalysisRouteExit,
            builder: (context, state) {
              final jobId = state.pathParameters['jobId']!;
              return CheckProcessingScreen(key: ValueKey(jobId), jobId: jobId);
            },
          ),
          GoRoute(
            path: '/checks/:groupId',
            builder: (context, state) => CheckDetailsScreen(
              groupId: state.pathParameters['groupId']!,
              initialGroup: state.extra is AnalysisReportGroup ? state.extra as AnalysisReportGroup : null,
            ),
          ),
          GoRoute(
            path: '/documents',
            builder: (context, state) => AppDesignSurface(
              child: DocumentsScreen(tab: DocumentsScreen.tabFrom(state.uri.queryParameters['tab'])),
            ),
          ),
          GoRoute(
            path: '/upload',
            builder: (context, state) => AppDesignSurface(
              child: UploadPrescriptionScreen(resumeDraft: state.uri.queryParameters['resume'] == 'true'),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const AppDesignSurface(child: ProfileScreen()),
            routes: [GoRoute(path: 'edit-name', builder: (_, _) => const EditNameScreen())],
          ),
          GoRoute(
            path: '/consent',
            builder: (context, state) => const AppDesignSurface(child: ConsentScreen()),
          ),
          GoRoute(
            path: '/upload-policy',
            builder: (context, state) => const AppDesignSurface(child: UploadPolicyScreen()),
          ),
          GoRoute(
            path: '/analysis',
            builder: (context, state) => const AppDesignSurface(child: AnalysisScreen()),
          ),
          GoRoute(
            path: '/analysis-multi',
            redirect: (_, state) {
              final jobId = state.uri.queryParameters['job'];
              return jobId == null || jobId.isEmpty
                  ? null
                  : '/check/processing/${Uri.encodeComponent(jobId)}';
            },
            builder: (context, state) => AppDesignSurface(
              child: MultiAnalysisScreen(
                resumeJobId: state.uri.queryParameters['job'],
                resumeSessionId: state.uri.queryParameters['session'],
              ),
            ),
          ),
          GoRoute(path: '/multi-analysis', redirect: (context, state) => '/analysis-multi'),
          GoRoute(
            path: '/summary',
            builder: (context, state) => const AppDesignSurface(child: SummaryScreen()),
          ),
          GoRoute(
            path: '/summary/:id',
            builder: (context, state) =>
                AppDesignSurface(child: SummaryScreen(reportId: state.pathParameters['id'])),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const AppDesignSurface(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/view-pdf/:fileId',
            builder: (context, state) {
              final fileId = state.pathParameters['fileId']!;
              final title = state.uri.queryParameters['title'] ?? 'Document';
              return PdfViewerScreen(fileId: fileId, title: title);
            },
          ),
          // Legacy redirects
          GoRoute(path: '/policies', redirect: (context, state) => '/documents?tab=policies'),
          GoRoute(path: '/prescriptions', redirect: (context, state) => '/documents?tab=prescriptions'),

          // ── Indexed tab shell: Home and History live here, keeping state ──
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => _TabShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                navigatorKey: _homeNavigatorKey,
                routes: [
                  GoRoute(
                    // Keep the old '/dashboard' path so existing deep-links still work.
                    path: AppRootNavigation.homePath,
                    builder: (context, state) => const AppDesignSurface(child: HomeScreen()),
                  ),
                ],
              ),
              StatefulShellBranch(
                navigatorKey: _historyNavigatorKey,
                routes: [
                  GoRoute(
                    path: AppRootNavigation.historyPath,
                    builder: (context, state) => const AppDesignSurface(child: AnalysesReportsScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Renders the indexed-stack tabs with the shared floating nav bar.
///
/// The nav is built once here and never rebuilds when switching tabs —
/// only the selected indicator pill animates (Phase F §0.9).
class _TabShell extends ConsumerStatefulWidget {
  const _TabShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<_TabShell> with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(vsync: this, animationBehavior: AnimationBehavior.preserve);
  late final _openedOnHome = widget.navigationShell.currentIndex == 0;
  bool _playedEntrance = false;

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  static void startCheck(BuildContext context) => context.push('/check/new');

  @override
  void didUpdateWidget(covariant _TabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex != widget.navigationShell.currentIndex &&
        widget.navigationShell.currentIndex == 1) {
      // Phase F §0.9: show cached History straight away and refresh silently.
      ref.read(analysisReportProvider.notifier).refreshInBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = DsMotion.reduced(context);
    final revealNav = _openedOnHome;
    if (!_playedEntrance && widget.navigationShell.currentIndex == 0) {
      _playedEntrance = true;
      _entrance.duration = reduced ? HomeEntrance.reducedDuration : HomeEntrance.duration;
      _entrance.forward();
    }

    return HomeEntrance(
      progress: _entrance,
      reduced: reduced,
      child: Stack(
        children: [
          // The indexed stack of tab pages sits behind the nav.
          widget.navigationShell,
          // Nav is positioned at the bottom, overlaying the content.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder(
              valueListenable: ref.watch(activeListSelectionProvider),
              builder: (context, selection, nav) => Offstage(
                offstage:
                    widget.navigationShell.currentIndex == 1 &&
                    selection?.path == AppRootNavigation.historyPath,
                child: nav,
              ),
              child: Builder(
                builder: (context) {
                  final nav = AppRootNavigation(
                    currentIndex: widget.navigationShell.currentIndex,
                    navigationShell: widget.navigationShell,
                    onNewCheck: () => startCheck(context),
                  );
                  return revealNav ? HomeReveal(delay: 320, duration: 300, rise: 16, child: nav) : nav;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
