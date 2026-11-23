import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/core/services/admob_service.dart';

/// Draggable floating Google AdMob banner (320x50) shown above the bottom nav.
///
/// Must be placed as a direct child of a [Stack]. The ad is never clipped or
/// covered (AdMob policy): the "Ad" label, drag handle and close button sit in
/// a header strip above it. The card stays invisible until an ad has loaded
/// and is removed if loading fails or the user closes it.
class FloatingBannerAd extends StatefulWidget {
  const FloatingBannerAd({super.key});

  @override
  State<FloatingBannerAd> createState() => _FloatingBannerAdState();
}

class _FloatingBannerAdState extends State<FloatingBannerAd> {
  static const AdSize _adSize = AdSize.banner;
  static const double _headerHeight = 22.0;
  static const double _bottomNavbarHeight = 90.0; // ShellRoute bottom bar + padding

  bool _loaded = false;
  bool _failed = false;
  bool _closed = false;
  Offset? _offset;

  @override
  Widget build(BuildContext context) {
    if (!AdMobConfig.isEnabled || _failed || _closed) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final padding = mq.padding;
    final p = context.palette;

    final cardWidth = _adSize.width + 2.0; // + border
    final cardHeight = _headerHeight + _adSize.height + 2.0;

    final minX = 8.0;
    final maxX = math.max(minX, screen.width - cardWidth - 8.0);
    final minY = padding.top + 8.0;
    final maxY = math.max(minY, screen.height - cardHeight - padding.bottom - _bottomNavbarHeight - 8.0);

    // Default: horizontally centred, just above the bottom navbar.
    _offset ??= Offset(((screen.width - cardWidth) / 2).clamp(minX, maxX), maxY);

    return Positioned(
      left: _offset!.dx.clamp(minX, maxX),
      top: _offset!.dy.clamp(minY, maxY),
      child: IgnorePointer(
        ignoring: !_loaded,
        child: AnimatedOpacity(
          opacity: _loaded ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: p.border),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: Column(
                children: [
                  // Header strip: drag handle + "Ad" label + close button (never over the ad).
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => setState(() {
                      _offset = Offset(
                        (_offset!.dx + d.delta.dx).clamp(minX, maxX),
                        (_offset!.dy + d.delta.dy).clamp(minY, maxY),
                      );
                    }),
                    child: Container(
                      height: _headerHeight,
                      color: p.surfaceMuted,
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'AD',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.drag_indicator_rounded, size: 14, color: p.textTertiary),
                          const Spacer(),
                          Semantics(
                            button: true,
                            label: 'Close advertisement',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _closed = true),
                              child: SizedBox(
                                width: 32,
                                height: _headerHeight,
                                child: Icon(Icons.close_rounded, size: 16, color: p.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AdMobBannerWidget(
                    adUnitId: AdMobConfig.floatingBannerAdUnitId,
                    adSize: _adSize,
                    onLoadResult: (loaded) {
                      if (!mounted) return;
                      setState(() {
                        _loaded = loaded;
                        _failed = !loaded;
                      });
                    },
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
