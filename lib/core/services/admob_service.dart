import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized configuration for Google AdMob.
///
/// To enable AdMob in the future:
/// 1. Set [isEnabled] = true (or define `ENABLE_ADMOB=true` in your `.env` file).
/// 2. Replace the test ad unit IDs below with your production AdMob credentials.
/// 3. Update the Application ID in:
///    - Android: `android/app/src/main/AndroidManifest.xml`
///    - iOS: `ios/Runner/Info.plist`
class AdMobConfig {
  AdMobConfig._();

  /// Reads a `.env` value without throwing. On Android the `.env` asset is
  /// stripped from the APK (dotfiles are ignored by the packager), so dotenv is
  /// usually NOT initialized and `dotenv.env` would throw mid-build.
  static String? _env(String key) {
    if (!dotenv.isInitialized) return null;
    try {
      return dotenv.env[key]?.trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }

  /// Compile-time default; disable with `--dart-define=ENABLE_ADMOB=false`.
  static const bool _defaultEnabled = bool.fromEnvironment('ENABLE_ADMOB', defaultValue: true);

  /// Master switch to enable/disable AdMob throughout the application.
  static bool get isEnabled {
    if (_forceEnabled != null) return _forceEnabled!;
    final envFlag = _env('ENABLE_ADMOB');
    if (envFlag == 'false' || envFlag == '0') return false;
    if (envFlag == 'true' || envFlag == '1') return true;
    return _defaultEnabled;
  }

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
  // Set ADMOB_FORCE_TEST_ADS=true in .env to force test IDs in release too.
  // ───────────────────────────────────────────────────────────────────────────

  static bool get _useTestAds {
    if (kDebugMode) return true;
    final flag = _env('ADMOB_FORCE_TEST_ADS');
    return flag == 'true' || flag == '1';
  }

  // Google's official test IDs
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  // Production IDs - Policy Pal (Android), App ID ca-app-pub-1082839767757375~5748331213
  static const _prodCarouselBannerAndroid = 'ca-app-pub-1082839767757375/6249612838';
  static const _prodFloatingBannerAndroid = 'ca-app-pub-1082839767757375/5692490890';
  static const _prodInterstitialAndroid = 'ca-app-pub-1082839767757375/1701274993';

  static String _pick({
    required String prodAndroid,
    required String testAndroid,
    required String testIos,
  }) {
    if (Platform.isAndroid) return _useTestAds ? testAndroid : prodAndroid;
    if (Platform.isIOS) return testIos;
    return '';
  }

  /// Carousel Banner Ad Unit ID (Dashboard top slider)
  static String get carouselBannerAdUnitId => _pick(
        prodAndroid: _prodCarouselBannerAndroid,
        testAndroid: _testBannerAndroid,
        testIos: _testBannerIos,
      );

  /// Floating Ad Banner Ad Unit ID (Dashboard draggable floating ad)
  static String get floatingBannerAdUnitId => _pick(
        prodAndroid: _prodFloatingBannerAndroid,
        testAndroid: _testBannerAndroid,
        testIos: _testBannerIos,
      );

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

/// A self-contained widget that loads and renders a Google AdMob banner ad.
/// Loads exactly one [BannerAd] per widget instance (the SDK refreshes it on
/// the ad unit's own schedule) and disposes it with the widget.
///
/// [onLoadResult] reports `true` once the ad has loaded and `false` if it
/// fails (no fill, ad blocker, AdMob disabled), so parents can hide the slot.
class AdMobBannerWidget extends StatefulWidget {
  final String adUnitId;
  final AdSize adSize;
  final ValueChanged<bool>? onLoadResult;

  const AdMobBannerWidget({
    super.key,
    required this.adUnitId,
    this.adSize = AdSize.banner,
    this.onLoadResult,
  });

  @override
  State<AdMobBannerWidget> createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<AdMobBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AdMobConfig.isEnabled || widget.adUnitId.isEmpty) {
      // Report after this frame so the parent never gets setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLoadResult?.call(false);
      });
      return;
    }

    _bannerAd = AdMobService.createBannerAd(
      adUnitId: widget.adUnitId,
      size: widget.adSize,
      onAdLoaded: (ad) {
        if (!mounted) return;
        setState(() => _isLoaded = true);
        widget.onLoadResult?.call(true);
      },
      onAdFailedToLoad: (ad, error) {
        // createBannerAd already disposed the failed ad.
        _bannerAd = null;
        if (!mounted) return;
        setState(() => _isLoaded = false);
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
    final width = widget.adSize.width.toDouble();
    final height = widget.adSize.height.toDouble();
    final ad = _bannerAd;

    return SizedBox(
      width: width,
      height: height,
      child: (_isLoaded && ad != null) ? AdWidget(ad: ad) : const SizedBox.shrink(),
    );
  }
}
