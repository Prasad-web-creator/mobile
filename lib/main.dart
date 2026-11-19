import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:claimsupport/core/theme/theme_provider.dart';
import 'package:claimsupport/core/routing/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/foundation.dart';
import 'package:claimsupport/core/config/env_config.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent release mode black screen on unhandled Flutter widget build errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exception}');
    return Material(
      color: const Color(0xFFF5F7FA),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                  child: const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C), size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This section could not be displayed. Please go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569)),
                ),
                if (!kReleaseMode) ...[
                  const SizedBox(height: 12),
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  };

  try {
    if (!kReleaseMode) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        debugPrint('No .env file found. Using default dev config.');
      }
    }

    EnvConfig.initialize(kReleaseMode ? Environment.prod : Environment.dev);
  } catch (e) {
    debugPrint('EnvConfig init error: $e');
  }

  try {
    await SharedPrefs.init();
  } catch (e) {
    debugPrint('SharedPrefs init error: $e');
  }

  try {
    await AuthStorage.migrateIfNeeded();
  } catch (e) {
    debugPrint('AuthStorage migration error: $e');
  }

  runApp(const ProviderScope(child: ClaimSupportApp()));
}

class ClaimSupportApp extends ConsumerWidget {
  const ClaimSupportApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Policy Pal',
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
