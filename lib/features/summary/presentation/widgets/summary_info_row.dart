import 'package:flutter/material.dart';

/// One "label : value" row, shared by the Policy Summary, Policy Continuity and
/// Prescription Summary cards so their labels and values line up in the same columns.
class SummaryInfoRow extends StatelessWidget {
  /// Width of the label column in every summary card.
  static const double labelWidth = 136;

  final String label;
  final String value;
  final String? detail;
  final Color? valueColor;
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
    final labelColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, height: 1.35, color: labelColor, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: valueColor ?? textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: TextStyle(fontSize: 11.5, height: 1.35, color: labelColor)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
