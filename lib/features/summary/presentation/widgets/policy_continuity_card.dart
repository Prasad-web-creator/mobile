import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/utils/json_utils.dart';
import 'package:claimsupport/features/summary/presentation/widgets/summary_info_row.dart';

/// Colour and icon for a continuity status code from the backend.
({Color color, IconData icon}) continuityStatusStyle(String statusCode) {
  switch (statusCode) {
    case 'VERIFIED':
      return (color: const Color(0xFF059669), icon: Icons.verified_outlined);
    case 'GAP_DETECTED':
      return (color: const Color(0xFFDC2626), icon: Icons.link_off_rounded);
    case 'CONFLICT':
      return (color: const Color(0xFFD97706), icon: Icons.warning_amber_rounded);
    default:
      return (color: const Color(0xFF6B7280), icon: Icons.help_outline_rounded);
  }
}

/// Policy Continuity section of the coverage report.
///
/// Renders the backend's deterministic continuity result as-is: when the
/// policy started, whether cover ran without a break to the claim date, and
/// the evidence that decision rests on. Nothing is re-derived here.
class PolicyContinuityCard extends StatelessWidget {
  final Map<String, dynamic> continuity;
  final bool isDark;

  const PolicyContinuityCard({
    super.key,
    required this.continuity,
    required this.isDark,
  });

  static String formatDate(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    return parsed == null ? text : DateFormat('dd MMM yyyy').format(parsed);
  }

  String _period(Map<String, dynamic> row) {
    final start = formatDate(row['startDate']);
    final end = formatDate(row['endDate']);
    if (start.isEmpty && end.isEmpty) return '';
    return '${start.isEmpty ? 'Not stated' : start} – ${end.isEmpty ? 'Not stated' : end}';
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);

    final status = continuity['status']?.toString() ?? '';
    final statusCode = continuity['statusCode']?.toString() ?? '';
    final summary = continuity['summary']?.toString() ?? '';
    final style = continuityStatusStyle(statusCode);

    final current = asMap(continuity['currentPolicy']);
    final gaps = asList(continuity['coverageGaps']).map(asMap).toList();
    final conflicts = asList(continuity['continuityConflicts']).map((e) => e.toString()).toList();
    final missing = asList(continuity['missingInformation']).map((e) => e.toString()).toList();


    final originalStart = formatDate(continuity['originalPolicyStartDate']);
    final earliestDocumented = formatDate(continuity['earliestDocumentedStartDate']);
    final claimDate = formatDate(continuity['claimDate']);
    final claimSource = continuity['claimDateSource']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 10),
              Text(
                'Policy Continuity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: style.color.withAlpha(isDark ? 40 : 22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: style.color.withAlpha(90)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(style.icon, color: style.color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status.isEmpty ? 'Continuity Cannot Be Established' : status,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: style.color),
                      ),
                    ),
                  ],
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(summary, style: TextStyle(fontSize: 12.5, height: 1.4, color: textColor)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Labels are kept to one line so every row lines up with the other summary cards.
          _row('First Start Date',
              originalStart.isNotEmpty
                  ? originalStart
                  : (earliestDocumented.isNotEmpty
                      ? 'Not established (earliest documented: $earliestDocumented)'
                      : 'Not established')),
          if (continuity['declared'] == true && continuity['isRenewal'] != null)
            _row('New / Renewed', continuity['isRenewal'] == false ? 'New policy (first year)' : 'Renewed policy'),
          if (formatDate(continuity['coverRestartDate']).isNotEmpty)
            _row('Cover Restarted', formatDate(continuity['coverRestartDate']),
                detail: 'Waiting periods count from this date'),
          _row('Current Period', _period(current).isEmpty ? 'Not stated' : _period(current),
              detail: current['label']?.toString()),
          _row('Claim Date', claimDate.isEmpty ? 'Not available' : claimDate,
              detail: claimSource.isEmpty ? null : 'From $claimSource'),
          _row('Continuity Status', status.isEmpty ? '—' : status, valueColor: style.color),

          // Gaps
          _label('Coverage Gap(s)', subColor),
          if (gaps.isEmpty)
            _bodyText(
              statusCode == 'CANNOT_BE_ESTABLISHED' || statusCode.isEmpty
                  ? 'None found in the documents provided (history incomplete).'
                  : 'None found.',
              textColor,
            )
          else
            ...gaps.map((g) {
              final days = g['days'];
              final fromDate = g['from'] != null ? formatDate(g['from']) : null;
              final toDate = g['to'] != null ? formatDate(g['to']) : null;
              final desc = g['description']?.toString();

              String title;
              String? detail;
              if (fromDate != null && toDate != null && days != null) {
                title = '$fromDate – $toDate ($days day${days == 1 ? '' : 's'})';
                detail = desc;
              } else if (desc != null && desc.isNotEmpty) {
                title = desc;
                detail = (toDate != null) ? 'Before $toDate' : null;
              } else {
                title = 'Policy renewal break / gap';
                detail = (toDate != null) ? 'Before $toDate' : null;
              }

              return _bullet(
                title,
                textColor,
                subColor,
                detail: detail,
                color: const Color(0xFFDC2626),
              );
            }),

          if (conflicts.isNotEmpty) ...[
            _label('Conflicts', subColor),
            ...conflicts.map((c) => _bullet(c, textColor, subColor, color: const Color(0xFFD97706))),
          ],

          if (missing.isNotEmpty && statusCode != 'VERIFIED') ...[
            _label('Information Not Available', subColor),
            ...missing.map((m) => _bullet(m, textColor, subColor)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {String? detail, Color? valueColor}) {
    return SummaryInfoRow(label: label, value: value, detail: detail, valueColor: valueColor, isDark: isDark);
  }

  Widget _label(String text, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subColor)),
    );
  }

  Widget _bodyText(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 13, color: textColor)),
    );
  }

  Widget _bullet(String text, Color textColor, Color subColor,
      {String? detail, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color ?? subColor, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: textColor,
                    )),
                if (detail != null && detail.isNotEmpty)
                  Text(detail, style: TextStyle(fontSize: 11.5, height: 1.4, color: subColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
