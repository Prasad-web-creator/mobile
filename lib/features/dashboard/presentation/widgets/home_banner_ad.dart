import 'package:flutter/material.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/core/services/admob_service.dart';

/// Home screen ad, styled as a regular dashboard card with a quiet
/// "Sponsored" tag. The banner is adaptive, so it fills the card width
/// instead of sitting as a small box in the middle.
///
/// The slot (including its spacing) stays collapsed until an ad has loaded,
/// and is removed if AdMob is disabled or no ad is available.
class HomeBannerAd extends StatefulWidget {
  const HomeBannerAd({super.key});

  @override
  State<HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<HomeBannerAd> {
  bool _loaded = false;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (!AdMobConfig.isEnabled || _failed) return const SizedBox.shrink();

    final p = context.palette;
    return AdSlotReveal(
      visible: _loaded,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AdSponsoredLabel(color: p.textTertiary),
                ),
              ),
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: AdMobBannerWidget(
                  adUnitId: AdMobConfig.carouselBannerAdUnitId,
                  layout: AdBannerLayout.inline,
                  inlineMaxHeight: 120,
                  onLoadResult: (loaded) {
                    if (!mounted) return;
                    setState(() {
                      _loaded = loaded;
                      _failed = !loaded;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
