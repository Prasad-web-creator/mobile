import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/core/utils/json_utils.dart';
import 'package:claimsupport/features/summary/presentation/widgets/summary_info_row.dart';

/// Tone and icon for a continuity status code from the backend.
({AppTone tone, IconData icon}) continuityStatusStyle(String statusCode) {
  switch (statusCode) {
    case 'VERIFIED':
      return (tone: AppTone.success, icon: Icons.verified_outlined);
    case 'GAP_DETECTED':
      return (tone: AppTone.danger, icon: Icons.link_off_rounded);
    case 'CONFLICT':
      return (tone: AppTone.warning, icon: Icons.warning_amber_rounded);
    default:
      return (tone: AppTone.neutral, icon: Icons.help_outline_rounded);
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

  const PolicyContinuityCard({super.key, required this.continuity, required this.isDark});

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
    final p = context.palette;
    final textColor = p.textPrimary;
    final subColor = p.textTertiary;

    final status = continuity['status']?.toString() ?? '';
    final statusCode = continuity['statusCode']?.toString() ?? '';
    final summary = continuity['summary']?.toString() ?? '';
    final style = continuityStatusStyle(statusCode);
    final tone = p.tone(style.tone);

    final current = asMap(continuity['currentPolicy']);
    final gaps = asList(continuity['coverageGaps']).map(asMap).toList();
    final conflicts = asList(continuity['continuityConflicts']).map((e) => e.toString()).toList();
    final missing = asList(continuity['missingInformation']).map((e) => e.toString()).toList();

    final originalStart = formatDate(continuity['originalPolicyStartDate']);
    final earliestDocumented = formatDate(continuity['earliestDocumentedStartDate']);
    final claimDate = formatDate(continuity['claimDate']);
    final claimSource = continuity['claimDateSource']?.toString() ?? '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle(title: 'Policy Continuity', icon: Icons.timeline_rounded, tone: AppTone.brand),
          const SizedBox(height: AppSpacing.md),

          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: tone.bg,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: tone.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(style.icon, color: tone.fg, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        status.isEmpty ? 'Continuity Cannot Be Established' : status,
                        style: context.text.titleSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: context.text.bodySmall?.copyWith(color: textColor, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Labels are kept to one line so every row lines up with the other summary cards.
          _row(
            'First Start Date',
            originalStart.isNotEmpty
                ? originalStart
                : (earliestDocumented.isNotEmpty
                      ? 'Not established (earliest documented: $earliestDocumented)'
                      : 'Not established'),
          ),
          if (continuity['declared'] == true && continuity['isRenewal'] != null)
            _row('New / Renewed', continuity['isRenewal'] == false ? 'New policy (first year)' : 'Renewed policy'),
          if (formatDate(continuity['coverRestartDate']).isNotEmpty)
            _row(
              'Cover Restarted',
              formatDate(continuity['coverRestartDate']),
              detail: 'Waiting periods count from this date',
            ),
          _row(
            'Current Period',
            _period(current).isEmpty ? 'Not stated' : _period(current),
            detail: current['label']?.toString(),
          ),
          _row(
            'Claim Date',
            claimDate.isEmpty ? 'Not available' : claimDate,
            detail: claimSource.isEmpty ? null : 'From $claimSource',
          ),
          _row('Continuity Status', status.isEmpty ? '—' : status, valueColor: tone.fg),

          // Gaps. A declared break has no known dates, so the section is hidden and
          // the summary above explains the gap.
          if (!(gaps.isEmpty && statusCode == 'GAP_DETECTED')) _label(context, 'Coverage Gap(s)', subColor),
          if (gaps.isEmpty && statusCode == 'GAP_DETECTED')
            const SizedBox.shrink()
          else if (gaps.isEmpty)
            _bodyText(
              context,
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

              return _bullet(context, title, textColor, subColor, detail: detail, color: p.danger.fg);
            }),

          if (conflicts.isNotEmpty) ...[
            _label(context, 'Conflicts', subColor),
            ...conflicts.map((c) => _bullet(context, c, textColor, subColor, color: p.warning.fg)),
          ],

          if (missing.isNotEmpty && statusCode != 'VERIFIED') ...[
            _label(context, 'Information Not Available', subColor),
            ...missing.map((m) => _bullet(context, m, textColor, subColor)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {String? detail, Color? valueColor}) {
    return SummaryInfoRow(label: label, value: value, detail: detail, valueColor: valueColor, isDark: isDark);
  }

  Widget _label(BuildContext context, String text, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: subColor,
        ),
      ),
    );
  }

  Widget _bodyText(BuildContext context, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: context.text.bodyMedium?.copyWith(color: textColor)),
    );
  }

  Widget _bullet(BuildContext context, String text, Color textColor, Color subColor, {String? detail, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: AppSpacing.xs),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color ?? subColor, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: context.text.bodyMedium?.copyWith(color: textColor, height: 1.4)),
                if (detail != null && detail.isNotEmpty)
                  Text(detail, style: context.text.bodySmall?.copyWith(color: subColor, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
