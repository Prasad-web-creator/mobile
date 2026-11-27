import 'package:claimsupport/core/design/design.dart';
import 'package:flutter/material.dart';

class AppSelectionCheckbox extends StatelessWidget {
  const AppSelectionCheckbox({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: 22,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: checked ? c.buttonPrimary : null,
          shape: DsShape.shape(8, side: BorderSide(color: checked ? c.buttonPrimary : c.borderStrong)),
        ),
        child: checked ? Icon(Icons.check, size: DsSize.iconXs, color: c.textOnButton) : null,
      ),
    );
  }
}
