import 'package:claimsupport/core/localization/localization.dart';
import 'package:flutter/material.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/services/admob_service.dart';

/// Full-width banner docked just above the bottom navigation bar.
///
/// It sits below the scrolling content (never on top of it), uses an adaptive
/// anchored size so it spans the screen edge to edge, and carries a small
/// context.l10n.sharedSponsored tag plus a close button in a strip above the ad (never over
/// the ad itself, per AdMob policy). Collapsed until an ad loads; removed if
/// loading fails or the user closes it for this session.
class DockedBannerAd extends StatefulWidget {
  const DockedBannerAd({super.key});

  @override
  State<DockedBannerAd> createState() => _DockedBannerAdState();
}

class _DockedBannerAdState extends State<DockedBannerAd> {
  bool _loaded = false;
  bool _failed = false;
  bool _closed = false;

  @override
  Widget build(BuildContext context) {
    if (!AdMobConfig.isEnabled || _failed || _closed) return const SizedBox.shrink();

    final c = context.colors;
    return AdSlotReveal(
      visible: _loaded,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceCard,
          border: Border(
            top: BorderSide(color: c.borderSubtle, width: DsShape.strokeHairline),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: DsSpace.screenPadding, right: DsSpace.s8),
              child: Row(
                children: [
                  Text(context.l10n.sharedSponsored, style: AppTextStyles.microStrong.copyWith(color: c.textTertiary)),
                  const Spacer(),
                  AppIconButton(
                    icon: AppIcons.close,
                    label: context.l10n.sharedHideAdvertisement,
                    onPressed: () => setState(() => _closed = true),
                  ),
                ],
              ),
            ),
            AdMobBannerWidget(
              adUnitId: AdMobConfig.floatingBannerAdUnitId,
              layout: AdBannerLayout.anchored,
              onLoadResult: (loaded) {
                if (!mounted) return;
                setState(() {
                  _loaded = loaded;
                  _failed = !loaded;
                });
              },
            ),
            const SizedBox(height: DsSpace.s4),
          ],
        ),
      ),
    );
  }
}
