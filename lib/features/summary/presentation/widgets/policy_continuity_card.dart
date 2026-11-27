import 'package:claimsupport/core/localization/translation_mapper.dart';
import 'package:claimsupport/core/localization/localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/core/utils/json_utils.dart';
import 'package:claimsupport/features/summary/presentation/widgets/summary_info_row.dart';
import 'package:claimsupport/features/summary/presentation/widgets/localized_policy_wording.dart';

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

  const PolicyContinuityCard({
    super.key,
    required this.continuity,
    required this.isDark,
  });

  static String formatDate(dynamic value, {String? locale}) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    return parsed == null
        ? text
        : DateFormat('dd MMM yyyy', dateFormatLocale(locale)).format(parsed);
  }

  String _period(BuildContext context, Map<String, dynamic> row) {
    final start = formatDate(row['startDate'], locale: context.l10n.localeName);
    final end = formatDate(row['endDate'], locale: context.l10n.localeName);
    if (start.isEmpty && end.isEmpty) return '';
    return '${start.isEmpty ? context.l10n.analysisNotStated : start} – ${end.isEmpty ? context.l10n.analysisNotStated : end}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final textColor = p.textPrimary;
    final subColor = p.textTertiary;

    final statusCode = continuity['statusCode']?.toString() ?? '';
    final l10n = context.l10n;
    final status = l10n.localeName == 'ta'
        ? switch (statusCode) {
            'VERIFIED' => l10n.analysisContinuityVerified,
            'GAP_DETECTED' => l10n.analysisContinuityGap,
            'CONFLICT' => l10n.analysisContinuityConflict,
            _ => l10n.analysisContinuityUnknown,
          }
        : continuity['status']?.toString() ?? '';
    final tamil = l10n.localeName == 'ta';
    final summary =
        reportNarrative(
          l10n,
          l10n.localeName,
          continuity['summary'],
          tamil ? continuity['summaryTa'] : null,
        ) ??
        '';
    final style = continuityStatusStyle(statusCode);
    final tone = p.tone(style.tone);

    final current = asMap(continuity['currentPolicy']);
    final gaps = asList(continuity['coverageGaps']).map(asMap).toList();
    List<String> details(String field) {
      final originals = asList(continuity[field]);
      final translated = tamil ? asList(continuity['${field}Ta']) : const [];
      return [
        for (var index = 0; index < originals.length; index++)
          if (reportNarrative(
                l10n,
                l10n.localeName,
                originals[index],
                index < translated.length ? translated[index] : null,
              )
              case final detail?)
            detail,
      ];
    }

    final conflicts = details('continuityConflicts');
    final missing = details('missingInformation');

    final originalStart = formatDate(
      continuity['originalPolicyStartDate'],
      locale: l10n.localeName,
    );
    final earliestDocumented = formatDate(
      continuity['earliestDocumentedStartDate'],
      locale: l10n.localeName,
    );
    final claimDate = formatDate(
      continuity['claimDate'],
      locale: l10n.localeName,
    );
    final claimSource =
        reportNarrative(
          l10n,
          l10n.localeName,
          continuity['claimDateSource'],
          tamil ? continuity['claimDateSourceTa'] : null,
        ) ??
        '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            title: context.l10n.analysisContinuity,
            icon: Icons.timeline_rounded,
            tone: AppTone.brand,
          ),
          const SizedBox(height: AppSpacing.md),

          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
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
                        status.isEmpty
                            ? context.l10n.analysisContinuityUnknown
                            : status,
                        style: context.text.titleSmall?.copyWith(
                          color: tone.fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: context.text.bodySmall?.copyWith(
                      color: textColor,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Labels are kept to one line so every row lines up with the other summary cards.
          _row(
            context.l10n.analysisFirstStartDate,
            originalStart.isNotEmpty
                ? originalStart
                : (earliestDocumented.isNotEmpty
                      ? context.l10n.analysisContinuityEarliest(
                          earliestDocumented,
                        )
                      : context.l10n.analysisNotEstablished),
          ),
          if (continuity['declared'] == true && continuity['isRenewal'] != null)
            _row(
              context.l10n.analysisNewRenewed,
              continuity['isRenewal'] == false
                  ? context.l10n.analysisNewFirstYear
                  : context.l10n.analysisRenewedPolicy,
            ),
          if (formatDate(
            continuity['coverRestartDate'],
            locale: context.l10n.localeName,
          ).isNotEmpty)
            _row(
              context.l10n.analysisCoverRestarted,
              formatDate(
                continuity['coverRestartDate'],
                locale: context.l10n.localeName,
              ),
              detail: context.l10n.analysisWaitingStarts,
            ),
          _row(
            context.l10n.analysisCurrentPeriod,
            _period(context, current).isEmpty
                ? context.l10n.analysisNotStated
                : _period(context, current),
            detail:
                (tamil
                        ? current['labelTa'] ?? current['label']
                        : current['label'])
                    ?.toString(),
          ),
          _row(
            context.l10n.analysisClaimDate,
            claimDate.isEmpty ? context.l10n.analysisNotAvailable : claimDate,
            detail: claimSource.isEmpty
                ? null
                : context.l10n.analysisClaimFrom(claimSource),
          ),
          _row(
            context.l10n.analysisContinuityStatus,
            status.isEmpty ? '—' : status,
            valueColor: tone.fg,
          ),

          // Gaps. A declared break has no known dates, so the section is hidden and
          // the summary above explains the gap.
          if (!(gaps.isEmpty && statusCode == 'GAP_DETECTED'))
            _label(context, context.l10n.analysisCoverageGaps, subColor),
          if (gaps.isEmpty && statusCode == 'GAP_DETECTED')
            const SizedBox.shrink()
          else if (gaps.isEmpty)
            _bodyText(
              context,
              statusCode == 'CANNOT_BE_ESTABLISHED' || statusCode.isEmpty
                  ? context.l10n.analysisNoGapsIncomplete
                  : context.l10n.analysisNoneFound,
              textColor,
            )
          else
            ...gaps.map((g) {
              final days = g['days'];
              final fromDate = g['from'] != null
                  ? formatDate(g['from'], locale: context.l10n.localeName)
                  : null;
              final toDate = g['to'] != null
                  ? formatDate(g['to'], locale: context.l10n.localeName)
                  : null;
              final desc = reportNarrative(
                l10n,
                l10n.localeName,
                g['description'],
                tamil ? g['descriptionTa'] : null,
              );

              String title;
              String? detail;
              if (fromDate != null && toDate != null && days != null) {
                title = context.l10n.analysisGapDateRange(
                  fromDate,
                  toDate,
                  days,
                );
                detail = desc;
              } else if (desc != null && desc.isNotEmpty) {
                title = desc;
                detail = (toDate != null)
                    ? context.l10n.analysisBeforeDate(toDate)
                    : null;
              } else {
                title = context.l10n.analysisRenewalGap;
                detail = (toDate != null)
                    ? context.l10n.analysisBeforeDate(toDate)
                    : null;
              }

              return _bullet(
                context,
                title,
                textColor,
                subColor,
                detail: detail,
                color: p.danger.fg,
              );
            }),

          if (conflicts.isNotEmpty) ...[
            _label(context, context.l10n.analysisConflicts, subColor),
            ...conflicts.map(
              (c) =>
                  _bullet(context, c, textColor, subColor, color: p.warning.fg),
            ),
          ],

          if (missing.isNotEmpty && statusCode != 'VERIFIED') ...[
            _label(context, context.l10n.analysisMissingInfo, subColor),
            ...missing.map((m) => _bullet(context, m, textColor, subColor)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {String? detail, Color? valueColor}) {
    return SummaryInfoRow(
      label: label,
      value: value,
      detail: detail,
      valueColor: valueColor,
      isDark: isDark,
    );
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
      child: Text(
        text,
        style: context.text.bodyMedium?.copyWith(color: textColor),
      ),
    );
  }

  Widget _bullet(
    BuildContext context,
    String text,
    Color textColor,
    Color subColor, {
    String? detail,
    Color? color,
  }) {
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
              decoration: BoxDecoration(
                color: color ?? subColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: context.text.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.4,
                  ),
                ),
                if (detail != null && detail.isNotEmpty)
                  Text(
                    detail,
                    style: context.text.bodySmall?.copyWith(
                      color: subColor,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
