import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/home_background.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/auth_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static Future<String> resolveDestination() async {
    final token = await AuthStorage.getToken();
    return token?.isNotEmpty == true ? '/dashboard' : '/login';
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final destination = await SplashScreen.resolveDestination();
    if (mounted) context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overlay = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: c.backgroundHome),
      child: Scaffold(
        backgroundColor: c.backgroundHome,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(top: 0, left: 0, right: 0, child: HomeBackground()),
            SafeArea(
              child: Align(
                alignment: const Alignment(0, -.08),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AuthBrandMark(size: 82),
                      const SizedBox(height: DsSpace.s24),
                      Text('Policy Pal', style: AppTextStyles.largeTitle.copyWith(color: c.textPrimary)),
                      const SizedBox(height: DsSpace.s6),
                      Text(
                        'Know what your policy covers',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subheadRegular.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
