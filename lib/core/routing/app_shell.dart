import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:claimsupport/core/design/widgets/floating_nav_bar.dart';

/// The shared floating nav that sits at the bottom of both tab screens.
///
/// When [navigationShell] is provided (StatefulShellRoute mode) tab switching
/// is instant with no reload. When null, the widget falls back to `context.go`
/// (used for screens that embed the nav outside the shell).
class AppRootNavigation extends StatelessWidget {
  const AppRootNavigation({
    super.key,
    required this.currentIndex,
    required this.onNewCheck,
    this.navigationShell,
  });

  static const homePath = '/dashboard';
  static const historyPath = '/reports';

  final int currentIndex;
  final VoidCallback onNewCheck;

  /// Non-null when rendered by [StatefulShellRoute.indexedStack].
  final StatefulNavigationShell? navigationShell;

  @override
  Widget build(BuildContext context) => FloatingNavBar(
    currentIndex: currentIndex,
    onNewCheck: onNewCheck,
    onTabSelected: (index) {
      if (index == currentIndex) return;
      final shell = navigationShell;
      if (shell != null) {
        // Instant switch — no page rebuild, state is preserved.
        shell.goBranch(index, initialLocation: index == shell.currentIndex);
      } else {
        // Fallback: plain GoRouter navigation.
        context.go(index == 0 ? homePath : historyPath);
      }
    },
  );
}
