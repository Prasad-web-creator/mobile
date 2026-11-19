import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

class FloatingAdItem {
  final String imageAsset;
  final String targetUrl;
  final String headline;

  const FloatingAdItem({required this.imageAsset, required this.targetUrl, required this.headline});
}

class FloatingLiveAd extends StatefulWidget {
  const FloatingLiveAd({super.key});

  @override
  State<FloatingLiveAd> createState() => _FloatingLiveAdState();
}

class _FloatingLiveAdState extends State<FloatingLiveAd> with SingleTickerProviderStateMixin {
  bool _isClosed = false;
  Offset? _offset;
  late final AnimationController _animController;
  late final Animation<double> _floatAnimation;

  final List<FloatingAdItem> _adItems = const [
    FloatingAdItem(
      imageAsset: 'assets/ag.png', // Accounts Guru
      targetUrl: 'https://accountsguru.io/',
      headline: 'Accounts Guru',
    ),
    FloatingAdItem(
      imageAsset: 'assets/r1.png', // Retail One
      targetUrl: 'https://retailone.cloud/',
      headline: 'Retail One',
    ),
  ];

  int _currentIndex = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    // Subtle floating animation (moves up and down by 4px over 2 seconds)
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: 0,
      end: -4,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    // Timer to cycle ads every 4 seconds
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && !_isClosed) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _adItems.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  Future<void> _launchAdUrl() async {
    final url = _adItems[_currentIndex].targetUrl;
    final uri = Uri.parse(url);
    debugPrint('[FloatingLiveAd] Tapped live ad. Launching $url');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[FloatingLiveAd] Launch error: $e');
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isClosed) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;

    const double adWidth = 105.0;
    const double adHeight = 155.0;
    const double bottomNavbarHeight = 90.0; // Height of ShellRoute BottomAppBar + padding

    // Initialize default position at bottom-right corner ABOVE bottom navbar
    _offset ??= Offset(
      screenSize.width - adWidth - 16.0,
      screenSize.height - adHeight - padding.bottom - bottomNavbarHeight - 16.0,
    );

    final double minX = 8.0;
    final double maxX = screenSize.width - adWidth - 8.0;
    final double minY = padding.top + 8.0;
    final double maxY = screenSize.height - adHeight - padding.bottom - bottomNavbarHeight - 8.0;

    final currentAd = _adItems[_currentIndex];
    final p = context.palette;

    return Positioned(
      left: _offset!.dx,
      top: _offset!.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            final newX = (_offset!.dx + details.delta.dx).clamp(minX, maxX);
            final newY = (_offset!.dy + details.delta.dy).clamp(minY, maxY);
            _offset = Offset(newX, newY);
          });
        },
        onTap: _launchAdUrl,
        child: AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, child) {
            return Transform.translate(offset: Offset(0, _floatAnimation.value), child: child);
          },
          child: Container(
            width: adWidth,
            height: adHeight,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: p.border),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: Stack(
                children: [
                  // ── Main Card Structure ────────────────────────────────
                  Column(
                    children: [
                      // Image Area (72% of card height)
                      Expanded(
                        flex: 72,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Animated Switcher for the Advertisement Image
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Image.asset(
                                currentAd.imageAsset,
                                key: ValueKey(currentAd.imageAsset),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    key: ValueKey('error_${currentAd.imageAsset}'),
                                    color: p.surfaceMuted,
                                    child: Center(
                                      child: Icon(Icons.shopping_bag_outlined, color: p.textTertiary, size: 28),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Bottom Dark Gradient for Headline Readability
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 38,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.black.withAlpha(200), Colors.transparent],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ),

                            // Short Headline Text
                            Positioned(
                              left: 6,
                              right: 6,
                              bottom: 4,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                child: Text(
                                  currentAd.headline,
                                  key: ValueKey(currentAd.headline),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    shadows: [Shadow(color: Color(0x80000000), blurRadius: 3)],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom CTA Strip (28% of card height)
                      Expanded(
                        flex: 28,
                        child: Container(
                          width: double.infinity,
                          color: p.primarySoft,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Visit Now',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.primary, fontSize: 11, fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Top Header Controls Overlay ────────────────────────
                  Positioned(
                    top: 2,
                    left: 6,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // LIVE Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Close (X) Button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isClosed = true;
                            });
                            debugPrint('[FloatingLiveAd] User closed the floating ad widget.');
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Semantics(
                            button: true,
                            label: 'Close advertisement',
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Center(
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(140),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withAlpha(90)),
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
