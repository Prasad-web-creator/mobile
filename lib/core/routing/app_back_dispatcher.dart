import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class AppBackDispatcher extends RootBackButtonDispatcher {
  AppBackDispatcher(
    this.router, {
    required this.root,
    required this.shell,
    required this.homePath,
    this.dismissSelection,
  });

  final GoRouter router;
  final BackRouteObserver root;
  final BackRouteObserver shell;
  final String homePath;
  final bool Function(String path)? dismissSelection;

  @override
  Future<bool> didPopRoute() async {
    final inApp = router.routerDelegate.currentConfiguration.matches.any((match) => match is ShellRouteMatch);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || !inApp || root.hasModal || shell.hasModal) {
      return super.didPopRoute();
    }
    final path = router.state.uri.path;
    if (dismissSelection?.call(path) == true) return true;
    if (path == homePath) {
      await SystemNavigator.pop();
    } else {
      router.go(homePath);
    }
    return true;
  }
}

class BackRouteObserver extends NavigatorObserver {
  bool hasModal = false;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    hasModal = topRoute.settings is! Page;
  }
}
