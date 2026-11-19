import 'package:flutter/material.dart';
import 'package:claimsupport/core/theme/app_palette.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/features/authentication/presentation/screens/splash_screen.dart';
import 'package:claimsupport/features/authentication/presentation/screens/login_screen.dart';
import 'package:claimsupport/features/authentication/presentation/screens/register_screen.dart';
import 'package:claimsupport/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:claimsupport/features/upload/presentation/screens/upload_prescription_screen.dart';
import 'package:claimsupport/features/upload/presentation/screens/upload_policy_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/consent_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/analysis_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/multi_analysis_screen.dart';
import 'package:claimsupport/features/summary/presentation/screens/summary_screen.dart';
import 'package:claimsupport/features/analyses_reports/presentation/screens/analyses_reports_screen.dart';
import 'package:claimsupport/features/profile/presentation/screens/profile_screen.dart';
import 'package:claimsupport/features/policies/presentation/screens/policy_list_screen.dart';
import 'package:claimsupport/features/prescriptions/presentation/screens/prescription_list_screen.dart';
import 'package:claimsupport/features/pdf_viewer/presentation/screens/pdf_viewer_screen.dart';

import 'package:claimsupport/features/benefits/presentation/screens/my_benefits_screen.dart';
import 'package:claimsupport/features/profile/presentation/screens/settings_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/splash'),
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      // Dashboard with Bottom Navigation using ShellRoute
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return Consumer(
            builder: (context, ref, _) {
              final theme = Theme.of(context);
              final palette = theme.extension<AppPalette>() ?? AppPalette.light;
              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                body: child,
                bottomNavigationBar: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: palette.border)),
                  ),
                  child: NavigationBar(
                    selectedIndex: _calculateSelectedIndex(state.uri.path),
                    onDestinationSelected: (index) => _onItemTapped(index, context, ref),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.assignment_outlined),
                        selectedIcon: Icon(Icons.assignment_rounded),
                        label: 'Reports',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.shield_outlined),
                        selectedIcon: Icon(Icons.shield_rounded),
                        label: 'My Benefits',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/reports', builder: (context, state) => const AnalysesReportsScreen()),
          GoRoute(path: '/upload', builder: (context, state) => const UploadPrescriptionScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/consent', builder: (context, state) => const ConsentScreen()),
          GoRoute(path: '/upload-policy', builder: (context, state) => const UploadPolicyScreen()),
          GoRoute(path: '/analysis', builder: (context, state) => const AnalysisScreen()),
          GoRoute(path: '/analysis-multi', builder: (context, state) => const MultiAnalysisScreen()),
          GoRoute(path: '/multi-analysis', redirect: (context, state) => '/analysis-multi'),
          GoRoute(path: '/summary', builder: (context, state) => const SummaryScreen()),
          GoRoute(
            path: '/summary/:id',
            builder: (context, state) => SummaryScreen(reportId: state.pathParameters['id']),
          ),
          GoRoute(path: '/policies', builder: (context, state) => const PolicyListScreen()),
          GoRoute(path: '/prescriptions', builder: (context, state) => const PrescriptionListScreen()),

          GoRoute(path: '/benefits', builder: (context, state) => const MyBenefitsScreen()),
          GoRoute(path: '/insights', redirect: (context, state) => '/benefits'),
          GoRoute(path: '/activity-logs', redirect: (context, state) => '/benefits'),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(
            path: '/view-pdf/:fileId',
            builder: (context, state) {
              final fileId = state.pathParameters['fileId']!;
              final title = state.uri.queryParameters['title'] ?? 'Document';
              return PdfViewerScreen(fileId: fileId, title: title);
            },
          ),
        ],
      ),
      // Other top-level screens
    ],
  );

  static int _calculateSelectedIndex(String location) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/reports')) return 1;
    if (location.startsWith('/benefits') || location.startsWith('/insights') || location.startsWith('/activity-logs') || location.startsWith('/logs')) {
      return 2;
    }
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  static void _onItemTapped(int index, BuildContext context, WidgetRef ref) {
    switch (index) {
      case 0:
        ref.invalidate(dashboardStatsProvider);
        context.go('/dashboard');
        break;
      case 1:
        ref.invalidate(analysisReportProvider);
        context.go('/reports');
        break;
      case 2:
        context.go('/benefits');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}
