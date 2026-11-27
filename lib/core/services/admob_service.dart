import 'package:claimsupport/core/localization/localization.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized configuration for Google AdMob.
///
/// To enable AdMob in the future:
/// 1. Build with `--dart-define=ENABLE_ADMOB=true`.
/// 2. Replace the test ad unit IDs below with your production AdMob credentials.
/// 3. Update the Application ID in:
///    - Android: `android/app/src/main/AndroidManifest.xml`
///    - iOS: `ios/Runner/Info.plist`
class AdMobConfig {
  AdMobConfig._();

  /// Compile-time default; disable with `--dart-define=ENABLE_ADMOB=false`.
  static const bool _defaultEnabled = bool.fromEnvironment('ENABLE_ADMOB', defaultValue: true);

  /// Master switch to enable/disable AdMob throughout the application.
  static bool get isEnabled => _forceEnabled ?? _defaultEnabled;

  /// In-memory override to toggle AdMob programmatically.
  static bool? _forceEnabled;

  /// Enable or disable AdMob dynamically.
  static void setEnabled(bool value) {
    _forceEnabled = value;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Application IDs (Configured in AndroidManifest.xml and Info.plist)
  // ───────────────────────────────────────────────────────────────────────────
  // Android Test App ID: ca-app-pub-3940256099942544~3347511713
  // iOS Test App ID:     ca-app-pub-3940256099942544~1458002511
  // ───────────────────────────────────────────────────────────────────────────

  // ───────────────────────────────────────────────────────────────────────────
  // Ad Unit IDs
  // Debug builds always use Google's test IDs (clicking live ads on your own
  // device can get the AdMob account suspended). Release builds use the
  // production IDs below. iOS has no production units yet, so it stays on test.
  // Use --dart-define=ADMOB_FORCE_TEST_ADS=true to force test IDs in release.
  // ───────────────────────────────────────────────────────────────────────────

  static bool get _useTestAds => kDebugMode || const bool.fromEnvironment('ADMOB_FORCE_TEST_ADS');

  // Google's official test IDs
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  // Production IDs - Policy Pal (Android), App ID ca-app-pub-1082839767757375~5748331213
  static const _prodCarouselBannerAndroid = 'ca-app-pub-1082839767757375/6249612838';
  static const _prodFloatingBannerAndroid = 'ca-app-pub-1082839767757375/5692490890';
  static const _prodInterstitialAndroid = 'ca-app-pub-1082839767757375/1701274993';

  static String _pick({required String prodAndroid, required String testAndroid, required String testIos}) {
    if (Platform.isAndroid) return _useTestAds ? testAndroid : prodAndroid;
    if (Platform.isIOS) return testIos;
    return '';
  }

  /// Carousel Banner Ad Unit ID (Dashboard top slider)
  static String get carouselBannerAdUnitId =>
      _pick(prodAndroid: _prodCarouselBannerAndroid, testAndroid: _testBannerAndroid, testIos: _testBannerIos);

  /// Floating Ad Banner Ad Unit ID (Dashboard draggable floating ad)
  static String get floatingBannerAdUnitId =>
      _pick(prodAndroid: _prodFloatingBannerAndroid, testAndroid: _testBannerAndroid, testIos: _testBannerIos);

  /// Interstitial Ad Unit ID (Full screen ads, for future workflows)
  static String get interstitialAdUnitId => _pick(
    prodAndroid: _prodInterstitialAndroid,
    testAndroid: _testInterstitialAndroid,
    testIos: _testInterstitialIos,
  );
}

/// Service to initialize and manage Google Mobile Ads (AdMob).
class AdMobService {
  AdMobService._();

  static bool _isInitialized = false;

  /// Initializes the Google Mobile Ads SDK if enabled.
  /// Safe to call during app startup (`main.dart`).
  static Future<void> init() async {
    if (!AdMobConfig.isEnabled) {
      debugPrint('[AdMobService] AdMob is currently disabled. Ad slots will be hidden.');
      return;
    }

    if (_isInitialized) return;

    try {
      final status = await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdMobService] Google Mobile Ads initialized successfully: ${status.adapterStatuses}');
    } catch (e) {
      debugPrint('[AdMobService] Failed to initialize Google Mobile Ads: $e');
    }
  }

  /// Creates a configured [BannerAd].
  static BannerAd createBannerAd({
    required String adUnitId,
    required AdSize size,
    void Function(Ad)? onAdLoaded,
    void Function(Ad, LoadAdError)? onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[AdMobService] BannerAd loaded successfully: ${ad.adUnitId}');
          onAdLoaded?.call(ad);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMobService] BannerAd failed to load: ${error.message} (Code: ${error.code})');
          ad.dispose();
          onAdFailedToLoad?.call(ad, error);
        },
      ),
    );
  }
}

/// How an adaptive banner is sized when no fixed [AdSize] is given.
enum AdBannerLayout {
  /// Inside scrolling content: full width, Google picks the height (up to a max).
  inline,

  /// Docked to the top/bottom of the screen: full width, fixed optimal height.
  anchored,
}

/// A self-contained widget that loads and renders a Google AdMob banner ad.
/// Loads exactly one [BannerAd] per widget instance (the SDK refreshes it on
/// the ad unit's own schedule) and disposes it with the widget.
///
/// With no [adSize], the banner is adaptive: it fills the available width so
/// it lines up with the surrounding cards instead of floating as a 320px box.
/// It takes no space until an ad has loaded.
///
/// [onLoadResult] reports `true` once the ad has loaded and `false` if it
/// fails (no fill, ad blocker, AdMob disabled), so parents can hide the slot.
class AdMobBannerWidget extends StatelessWidget {
  final String adUnitId;
  final AdSize? adSize;
  final AdBannerLayout layout;
  final int inlineMaxHeight;
  final ValueChanged<bool>? onLoadResult;

  const AdMobBannerWidget({
    super.key,
    required this.adUnitId,
    this.adSize,
    this.layout = AdBannerLayout.inline,
    this.inlineMaxHeight = 120,
    this.onLoadResult,
  });

  @override
  Widget build(BuildContext context) {
    if (adSize != null) {
      return _BannerLoader(adUnitId: adUnitId, fixedSize: adSize, onLoadResult: onLoadResult);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth.truncate() : 320;
        return _BannerLoader(
          // Reload only when the slot width really changes (e.g. rotation).
          key: ValueKey('$adUnitId-$width'),
          adUnitId: adUnitId,
          width: width,
          layout: layout,
          inlineMaxHeight: inlineMaxHeight,
          onLoadResult: onLoadResult,
        );
      },
    );
  }
}

class _BannerLoader extends StatefulWidget {
  final String adUnitId;
  final AdSize? fixedSize;
  final int width;
  final AdBannerLayout layout;
  final int inlineMaxHeight;
  final ValueChanged<bool>? onLoadResult;

  const _BannerLoader({
    super.key,
    required this.adUnitId,
    this.fixedSize,
    this.width = 320,
    this.layout = AdBannerLayout.inline,
    this.inlineMaxHeight = 120,
    this.onLoadResult,
  });

  @override
  State<_BannerLoader> createState() => _BannerLoaderState();
}

class _BannerLoaderState extends State<_BannerLoader> {
  BannerAd? _bannerAd;
  AdSize? _shownSize;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _report(bool loaded) {
    // Report after this frame so the parent never gets setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadResult?.call(loaded);
    });
  }

  Future<AdSize> _resolveSize() async {
    final fixed = widget.fixedSize;
    if (fixed != null) return fixed;
    if (widget.layout == AdBannerLayout.anchored) {
      try {
        final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(widget.width);
        if (size != null) return size;
      } catch (e) {
        debugPrint('[AdMobService] Adaptive size unavailable, using standard banner: $e');
      }
      return AdSize.banner;
    }
    return AdSize.getInlineAdaptiveBannerAdSize(widget.width, widget.inlineMaxHeight);
  }

  Future<void> _loadAd() async {
    if (!AdMobConfig.isEnabled || widget.adUnitId.isEmpty) {
      _report(false);
      return;
    }

    final requested = await _resolveSize();
    if (!mounted) return;

    _bannerAd = AdMobService.createBannerAd(
      adUnitId: widget.adUnitId,
      size: requested,
      onAdLoaded: (ad) async {
        // Inline adaptive ads only know their real height after loading.
        final actual = await (ad as BannerAd).getPlatformAdSize();
        if (!mounted) return;
        setState(() => _shownSize = actual ?? requested);
        widget.onLoadResult?.call(true);
      },
      onAdFailedToLoad: (ad, error) {
        // createBannerAd already disposed the failed ad.
        _bannerAd = null;
        if (!mounted) return;
        setState(() => _shownSize = null);
        widget.onLoadResult?.call(false);
      },
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    final size = _shownSize;
    if (ad == null || size == null || size.height <= 0) return const SizedBox.shrink();

    return Center(
      child: SizedBox(
        width: size.width.toDouble(),
        height: size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

/// Small, calm context.l10n.sharedSponsored tag that marks an ad slot without shouting.
class AdSponsoredLabel extends StatelessWidget {
  final Color color;

  const AdSponsoredLabel({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.campaign_outlined, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          context.l10n.sharedSponsored,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ],
    );
  }
}

/// Keeps an ad slot mounted (so its ad can load) but collapsed to zero height
/// until [visible] is true, then slides it open smoothly. No empty grey box
/// and no sudden layout jump.
class AdSlotReveal extends StatelessWidget {
  final bool visible;
  final Widget child;

  const AdSlotReveal({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: visible ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}
