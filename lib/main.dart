import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:claimsupport/core/theme/theme_provider.dart';
import 'package:claimsupport/core/routing/app_router.dart';

import 'package:flutter/foundation.dart';
import 'package:claimsupport/core/config/env_config.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/android_navigation_background.dart';
import 'package:claimsupport/core/design/widgets/startup_artwork.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/core/services/admob_service.dart';
import 'package:claimsupport/core/services/error_reporting.dart';
import 'package:claimsupport/features/home/data/home_check_cache.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(RootShell.systemNavigationStyle);

  // Prevent release mode black screen on unhandled Flutter widget build errors
  ErrorWidget.builder = (details) => Builder(
    builder: (context) {
      final c = context.colors;
      return Material(
        color: c.backgroundPage,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DsSpace.s24),
              child: Column(
                children: [
                  Icon(AppIcons.warning, color: c.statusNotCovered, size: DsSize.iconXl),
                  const SizedBox(height: DsSpace.s16),
                  Text(
                    'Something went wrong',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headline.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: DsSpace.s8),
                  Text(
                    'This section could not be displayed. Please go back and try again.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(color: c.textSecondary),
                  ),
                  if (!kReleaseMode) ...[
                    const SizedBox(height: DsSpace.s12),
                    Text(
                      details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  try {
    EnvConfig.initialize(kReleaseMode ? Environment.prod : Environment.dev);
  } catch (e) {
    debugPrint('EnvConfig init error: $e');
  }

  try {
    await SharedPrefs.init();
  } catch (e) {
    debugPrint('SharedPrefs init error: $e');
  }

  // Token reads wait for the one-time migration (see AuthStorage.getToken).
  AuthStorage.startMigration();
  try {
    await configureErrorReporting();
  } catch (_) {
    debugPrint('Error reporting could not be initialized.');
  }
  // Android keeps its native splash visible until the destination's first frame.
  final cachedHome = HomeCheckCache.restore();
  await AppRouter.prepareStartup();
  final homeCache = await cachedHome;
  WidgetsBinding.instance.deferFirstFrame();
  runApp(
    ProviderScope(
      overrides: [restoredHomeCacheProvider.overrideWithValue(homeCache)],
      child: const ClaimSupportApp(precacheArtwork: true),
    ),
  );

  AdMobService.init().catchError((Object e) => debugPrint('AdMobService init error: $e'));
}

class ClaimSupportApp extends ConsumerWidget {
  const ClaimSupportApp({super.key, this.precacheArtwork = false});

  final bool precacheArtwork;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Policy Pal',
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: AppRouter.config,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: AndroidNavigationBackground(child: precacheArtwork ? StartupArtwork(child: child!) : child!),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
