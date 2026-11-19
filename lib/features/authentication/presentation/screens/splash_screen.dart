import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';

/// Brand colours sampled from the app icon (assets/logo.png).
const _brandNavy = Color(0xFF0B2350);
const _brandBlue = Color(0xFF0D47B5);
const _brandTeal = Color(0xFF14C3A0);

/// Launch screen: brand gradient, logo, wordmark and a slim progress bar.
/// Matches the Android system splash colour (navy) so there is no white flash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _logoFade = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );
    _textFade = CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.85, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.85, curve: Curves.easeOutCubic)),
    );
    _footerFade = CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeOut));
    _controller.forward();
    _checkSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    try {
      final token = await AuthStorage.getToken();
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        context.go('/dashboard');
        return;
      }
    } catch (e) {
      debugPrint('Session check error: $e');
    }
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = math.min(112.0, size.width * 0.28);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0B3A6E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _brandNavy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Brand gradient: navy at the top, blue through the middle, a hint of teal at the bottom.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_brandNavy, _brandBlue, Color(0xFF0B6F8E)],
                  stops: [0.0, 0.62, 1.0],
                ),
              ),
            ),
            // Soft glow behind the logo.
            Align(
              alignment: const Alignment(0, -0.16),
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size.square(size.width * 1.15),
                  painter: _RingsPainter(),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          width: logoSize,
                          height: logoSize,
                          padding: EdgeInsets.all(logoSize * 0.06),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(logoSize * 0.26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(60),
                                blurRadius: 36,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(logoSize * 0.2),
                            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FadeTransition(
                      opacity: _textFade,
                      child: SlideTransition(
                        position: _textSlide,
                        child: Column(
                          children: [
                            Text(
                              'Policy Pal',
                              textAlign: TextAlign.center,
                              style: context.text.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Know your cover before you claim',
                              textAlign: TextAlign.center,
                              style: context.text.bodyLarge?.copyWith(
                                color: Colors.white.withAlpha(205),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 6),
                    FadeTransition(
                      opacity: _footerFade,
                      child: Column(
                        children: [
                          const _BrandLoadingBar(),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white.withAlpha(150)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Your policy data stays private and secure',
                                  textAlign: TextAlign.center,
                                  style: context.text.bodySmall?.copyWith(color: Colors.white.withAlpha(160)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft teal glow behind the logo.
class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Soft teal glow right behind the logo.
    canvas.drawCircle(
      center,
      size.width * 0.22,
      Paint()
        ..shader = RadialGradient(colors: [_brandTeal.withAlpha(45), _brandTeal.withAlpha(0)])
            .createShader(Rect.fromCircle(center: center, radius: size.width * 0.22)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slim indeterminate bar: a white segment sliding along a faint track.
class _BrandLoadingBar extends StatefulWidget {
  const _BrandLoadingBar();

  @override
  State<_BrandLoadingBar> createState() => _BrandLoadingBarState();
}

class _BrandLoadingBarState extends State<_BrandLoadingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const trackWidth = 120.0;
    const segWidth = 44.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: trackWidth,
        height: 3,
        color: Colors.white.withAlpha(40),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_c.value);
            final left = -segWidth + t * (trackWidth + segWidth);
            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: segWidth,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.white, _brandTeal]),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
