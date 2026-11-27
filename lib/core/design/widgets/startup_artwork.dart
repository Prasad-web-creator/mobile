import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';

/// Decodes the launch artwork before attaching the router and starting its animations.
class StartupArtwork extends StatefulWidget {
  const StartupArtwork({super.key, required this.child});

  final Widget child;

  @override
  State<StartupArtwork> createState() => _StartupArtworkState();
}

class _StartupArtworkState extends State<StartupArtwork> {
  bool _started = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    try {
      await Future.wait([
        for (final screen in ['home', 'auth'])
          for (final mode in ['light', 'dark'])
            precacheImage(AssetImage('assets/backgrounds/${screen}_bg_$mode.png'), context),
        for (final palette in [AppIllustrationColors.light, AppIllustrationColors.dark])
          for (final kind in AppIllustrationKind.values) _precacheIllustration(kind, palette),
      ]);
    } finally {
      if (mounted) setState(() => _ready = true);
      WidgetsBinding.instance.allowFirstFrame();
    }
  }

  Future<void> _precacheIllustration(AppIllustrationKind kind, AppIllustrationColors palette) async {
    final loader = SvgAssetLoader(kind.asset, colorMapper: IllustrationColorMapper(palette));
    try {
      await svg.cache.putIfAbsent(loader.cacheKey(context), () => loader.loadBytes(context));
    } catch (_) {
      // The illustration widget handles decoding errors when it mounts.
    }
  }

  @override
  Widget build(BuildContext context) => _ready ? widget.child : const SizedBox.shrink();
}
