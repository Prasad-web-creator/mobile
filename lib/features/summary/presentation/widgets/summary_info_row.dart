import 'package:flutter/material.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

/// One "label : value" row, shared by the Policy Summary, Policy Continuity and
/// Prescription Summary cards so their labels and values line up in the same columns.
///
/// Delegates to the design-system [KeyValueRow], which stacks the label above
/// the value on narrow screens / large font scales.
class SummaryInfoRow extends StatelessWidget {
  /// Width of the label column in every summary card.
  static const double labelWidth = 128;

  final String label;
  final String value;
  final String? detail;
  final Color? valueColor;

  /// Kept for API compatibility; colours now come from the theme palette.
  final bool isDark;

  const SummaryInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.isDark,
    this.detail,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return KeyValueRow(label: label, value: value, detail: detail, valueColor: valueColor, labelWidth: labelWidth);
  }
}
