import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/core/services/admob_service.dart';

/// Home screen banner slot served entirely by Google AdMob (320x100 large banner).
///
/// The slot (including its spacing) collapses when AdMob is disabled or no ad
/// can be loaded, so the dashboard never shows an empty box.
class HomeBannerAd extends StatefulWidget {
  const HomeBannerAd({super.key});

  @override
  State<HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<HomeBannerAd> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (!AdMobConfig.isEnabled || _failed) return const SizedBox.shrink();

    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surfaceMuted,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: p.border),
        ),
        child: AdMobBannerWidget(
          adUnitId: AdMobConfig.carouselBannerAdUnitId,
          adSize: AdSize.largeBanner,
          onLoadResult: (loaded) {
            if (!loaded && mounted) setState(() => _failed = true);
          },
        ),
      ),
    );
  }
}
