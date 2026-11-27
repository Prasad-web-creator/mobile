import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:claimsupport/core/design/app_icons.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_pressable.dart';

/// Floating bottom bar (Phase F §0.9): a frosted pill with two labelled tabs
/// (Home, History) and a separate blue "New check" button beside it.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onNewCheck,
  });

  static double _bottomOffset(BuildContext context) =>
      MediaQuery.of(context).viewPadding.bottom + DsSpace.s16;

  static double scrollClearance(BuildContext context) =>
      DsSpace.s8 + DsSize.control2xl + _bottomOffset(context);

  /// 0 = Home, 1 = History.
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onNewCheck;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = DsMotion.reduced(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, _bottomOffset(context)),
      child: SizedBox(
        height: DsSize.control2xl,
        child: Row(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: DsShape.shape(DsShape.radiusFull),
                  shadows: [DsEffect.checkStackShadow(lift: 1)],
                ),
                child: ClipRSuperellipse(
                  borderRadius: const BorderRadius.all(Radius.circular(DsShape.radiusFull)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: DsEffect.navBlur, sigmaY: DsEffect.navBlur),
                    child: Container(
                      padding: const EdgeInsets.all(DsSpace.s4),
                      decoration: ShapeDecoration(
                        color: c.surfaceNavBar,
                        shape: DsShape.shape(
                          DsShape.radiusFull,
                          side: BorderSide(color: c.borderSubtle, width: DsShape.strokeHairline),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AnimatedAlign(
                              alignment: currentIndex == 0
                                  ? AlignmentDirectional.centerStart
                                  : AlignmentDirectional.centerEnd,
                              duration: reduced ? Duration.zero : DsMotion.base,
                              curve: Curves.easeOut,
                              child: FractionallySizedBox(
                                widthFactor: 0.5,
                                heightFactor: 1,
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: c.surfaceSelected,
                                    shape: DsShape.shape(DsShape.radiusFull),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _NavTab(
                                  label: 'Home',
                                  icon: AppIcons.house,
                                  activeIcon: AppIcons.houseFill,
                                  selected: currentIndex == 0,
                                  onTap: () => onTabSelected(0),
                                ),
                              ),
                              Expanded(
                                child: _NavTab(
                                  label: 'History',
                                  icon: AppIcons.history,
                                  activeIcon: AppIcons.historyFill,
                                  selected: currentIndex == 1,
                                  onTap: () => onTabSelected(1),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: DsSpace.s8),
            _NewCheckButton(onTap: onNewCheck),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.iconActive : c.iconDefault;
    return Semantics(
      selected: selected,
      child: AppPressable(
        onTap: onTap,
        semanticLabel: label,
        child: SizedBox(
          height: DsSize.tabHeight,
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? activeIcon : icon, size: DsSize.iconXl, color: color),
                const SizedBox(height: DsSpace.s2),
                Text(
                  label,
                  maxLines: 1,
                  style: (selected ? AppTextStyles.microStrong : AppTextStyles.microRegular).copyWith(
                    color: color,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewCheckButton extends StatefulWidget {
  const _NewCheckButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_NewCheckButton> createState() => _NewCheckButtonState();
}

class _NewCheckButtonState extends State<_NewCheckButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AppPressable(
        onTap: widget.onTap,
        haptic: true,
        semanticLabel: 'New check',
        child: AnimatedContainer(
          duration: DsMotion.fast,
          height: DsSize.control2xl,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
          decoration: ShapeDecoration(
            color: _pressed ? c.buttonPrimaryPressed : c.buttonPrimary,
            shape: DsShape.shape(DsShape.radiusFull),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.scan, size: DsSize.iconLg, color: c.textOnButton),
                const SizedBox(width: DsSpace.s8),
                Text(
                  'New check',
                  style: AppTextStyles.subheadStrong.copyWith(
                    color: c.textOnButton,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
