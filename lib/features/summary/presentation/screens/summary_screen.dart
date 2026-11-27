import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/utils/json_utils.dart';
import 'package:claimsupport/core/utils/text_points.dart';
import 'package:claimsupport/features/summary/presentation/widgets/coverage_donut_chart.dart';
import 'package:claimsupport/features/summary/presentation/widgets/policy_continuity_card.dart';
import 'package:claimsupport/features/summary/presentation/widgets/summary_info_row.dart';

import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// Status of an item whose coverage depends on a detail not yet known
/// (for example eye power in dioptres for LASIK).
const String _needsVerification = 'Needs Verification';

class SummaryScreen extends ConsumerStatefulWidget {
  final String? reportId;
  final Map<String, dynamic>? reportSnapshot;
  const SummaryScreen({super.key, this.reportId, this.reportSnapshot});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    if (widget.reportSnapshot case final snapshot?) return snapshot;
    if (widget.reportId != null) {
      final response = await ApiClient().dio.get('/analysis/${widget.reportId}');
      return response.data as Map<String, dynamic>;
    }

    final prefs = SharedPrefs.instance;
    final resultStr = prefs.getString('analysis_result');
    if (resultStr != null) {
      return jsonDecode(resultStr) as Map<String, dynamic>;
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return PushedShell(
              key: const ValueKey('loading'),
              title: 'Coverage Summary',
              onBack: goBack,
              body: const LoadingState(message: 'Loading coverage report…'),
            );
          }

          if (snapshot.hasError) {
            return PushedShell(
              key: const ValueKey('report-error'),
              title: 'Coverage Summary',
              onBack: goBack,
              body: Center(
                child: ErrorState(
                  title: 'Couldn’t load the report',
                  message: friendlyErrorMessage(snapshot.error),
                  onRetry: () => setState(() => _dataFuture = _loadData()),
                ),
              ),
            );
          }
          final data = snapshot.data ?? {};
          final coverage = _CoveragePercent.from(data);
          final coverageBreakdown = data['coverageBreakdown'] as Map<String, dynamic>? ?? {};
          final overallStatus = data['overallStatus'] ?? 'Unknown';
          final comparison = asList(data['comparison']);
          final manualItems = comparison.where((item) {
            if (item is! Map) return false;
            final status = item['coverageStatus'] ?? item['status'];
            return status.toString().trim().toLowerCase() == 'manual review';
          }).length;
          final manualReviewCount = int.tryParse(coverageBreakdown['manualReview'].toString()) ?? manualItems;
          final allItemsNeedManualReview = manualReviewCount > 0 && manualReviewCount == comparison.length;
          final reviewMessage = manualReviewCount == 1
              ? '1 item needs manual review before coverage can be determined.'
              : '$manualReviewCount items need manual review before coverage can be determined.';
          final policyJson = data['policyJson'] as Map<String, dynamic>? ?? {};
          final prescriptionJson = data['prescriptionJson'] as Map<String, dynamic>? ?? {};
          final processingTime = data['processingTimeMs'] ?? 0;
          // Clarification Q&A from LLM interactive session
          final clarificationQA = asList(data['clarificationAnswersUsed']);

          // Document & validation statuses
          final docValidity = data['documentValidity'] as Map<String, dynamic>?;
          bool isPolicyValid = true;
          bool isPrescriptionValid = true;

          if (docValidity != null) {
            if (docValidity['policyValid'] == false || docValidity['isPolicyValid'] == false) {
              isPolicyValid = false;
            }
            if (docValidity['prescriptionValid'] == false || docValidity['isPrescriptionValid'] == false) {
              isPrescriptionValid = false;
            }
          }

          final policyStatusVal = (data['policyStatus'] ?? data['policyValidationStatus'] ?? '')
              .toString()
              .toLowerCase();
          if (policyStatusVal == 'invalid') {
            isPolicyValid = false;
          }

          final rxStatusVal = (data['prescriptionStatus'] ?? data['prescriptionValidationStatus'] ?? '')
              .toString()
              .toLowerCase();
          if (rxStatusVal == 'invalid') {
            isPrescriptionValid = false;
          }

          // Check contents of policy and prescription defensively
          final isCompanyEmpty =
              (policyJson['insuranceCompany'] == null ||
              policyJson['insuranceCompany'].toString().trim().isEmpty ||
              policyJson['insuranceCompany'].toString().toLowerCase() == 'unknown' ||
              policyJson['insuranceCompany'].toString().toLowerCase() == 'none');
          final isPolicyNumEmpty =
              (policyJson['policyNumber'] == null ||
              policyJson['policyNumber'].toString().trim().isEmpty ||
              policyJson['policyNumber'].toString().toLowerCase() == 'unknown' ||
              policyJson['policyNumber'].toString().toLowerCase() == 'none');
          final isPolicyNameEmpty =
              (policyJson['policyName'] == null ||
              policyJson['policyName'].toString().trim().isEmpty ||
              policyJson['policyName'].toString().toLowerCase() == 'unknown' ||
              policyJson['policyName'].toString().toLowerCase() == 'none');

          if (isCompanyEmpty && isPolicyNumEmpty && isPolicyNameEmpty && comparison.isEmpty) {
            isPolicyValid = false;
          }

          final isDiagEmpty =
              (prescriptionJson['diagnosis'] == null ||
              prescriptionJson['diagnosis'].toString().trim().isEmpty ||
              prescriptionJson['diagnosis'].toString().toLowerCase() == 'unknown' ||
              prescriptionJson['diagnosis'].toString().toLowerCase() == 'none');
          final hasRxItems =
              asList(prescriptionJson['medicines']).isNotEmpty ||
              asList(prescriptionJson['medicalTests']).isNotEmpty ||
              asList(prescriptionJson['procedures']).isNotEmpty ||
              asList(prescriptionJson['symptoms']).isNotEmpty;

          final isManualRx =
              prescriptionJson['isManual'] == true ||
              data['isManualPrescription'] == true ||
              prescriptionJson['prescriptionSource'] == 'Self-entered Prescription' ||
              (prescriptionJson['manualText'] != null && prescriptionJson['manualText'].toString().isNotEmpty);

          if (isDiagEmpty && !hasRxItems && comparison.isEmpty && !isManualRx) {
            isPrescriptionValid = false;
          }

          final lowerOverall = overallStatus.toLowerCase();
          if (lowerOverall.startsWith('invalid policy and prescription') ||
              (lowerOverall.contains('invalid policy') && lowerOverall.contains('prescription')) ||
              (lowerOverall.contains('policy and prescription') && lowerOverall.contains('invalid'))) {
            isPolicyValid = false;
            isPrescriptionValid = false;
          } else if (lowerOverall.startsWith('invalid policy') || lowerOverall.contains('invalid policy')) {
            isPolicyValid = false;
          } else if (lowerOverall.startsWith('invalid prescription') || lowerOverall.contains('invalid prescription')) {
            isPrescriptionValid = false;
          } else if (lowerOverall.startsWith('invalid')) {
            isPolicyValid = false;
            isPrescriptionValid = false;
          } else if (lowerOverall == 'unknown' || lowerOverall.isEmpty) {
            if (!isPolicyValid && !isPrescriptionValid) {
              isPolicyValid = false;
              isPrescriptionValid = false;
            } else if (!isPolicyValid) {
              isPolicyValid = false;
            } else if (!isPrescriptionValid) {
              isPrescriptionValid = false;
            } else if (comparison.isEmpty) {
              isPrescriptionValid = false;
            }
          }

          final bool isDocumentInvalid =
              !isPolicyValid || !isPrescriptionValid || lowerOverall.startsWith('invalid') || lowerOverall == 'unknown';

          // Determine specific invalid status title and disclaimer
          String invalidStatusTitle = 'Invalid Document';
          String invalidDisclaimer =
              'The uploaded document(s) could not be analyzed because they are invalid or unsupported. Please ensure you upload valid health insurance policy and medical prescription documents and try again.';

          if (!isPolicyValid && !isPrescriptionValid) {
            invalidStatusTitle = 'Invalid Policy and Prescription';
            invalidDisclaimer =
                'The uploaded Policy and Prescription documents could not be analyzed because they are invalid, unreadable, or unsupported. Please ensure you upload a valid health insurance policy and a medical prescription document (PDF, JPG, PNG) and try again.';
          } else if (!isPolicyValid) {
            invalidStatusTitle = 'Invalid Policy';
            invalidDisclaimer =
                'The uploaded Policy document could not be analyzed because it is invalid, unreadable, or unsupported. Please ensure you upload a valid health insurance policy document (PDF, JPG, PNG) and try again.';
          } else if (!isPrescriptionValid) {
            invalidStatusTitle = 'Invalid Prescription';
            if (isManualRx) {
              invalidDisclaimer =
                  'The self-entered prescription is not valid. Please provide valid medical details (such as diagnosis, symptoms, diseases, medicines, or medical tests) and try again.';
            } else {
              invalidDisclaimer =
                  'The uploaded Prescription document could not be analyzed because it is invalid, unreadable, or unsupported. Please ensure you upload a valid medical prescription document (PDF, JPG, PNG) and try again.';
            }
          }

          final Map<String, dynamic>? docMap =
              docValidity ??
              ((data['coverageAnalysis'] is Map)
                  ? (data['coverageAnalysis']['documentValidity'] as Map<String, dynamic>?)
                  : null);

          String rxInvalidReasonText = docMap?['prescriptionInvalidReason']?.toString() ?? '';
          if (rxInvalidReasonText.isEmpty) {
            if (isManualRx) {
              rxInvalidReasonText =
                  'The self-entered text contains no recognizable medical details (no diagnosis, symptoms, diseases, medicines, or medical tests).';
            } else {
              rxInvalidReasonText =
                  'The uploaded document contains no valid diagnosis, medicines, medical tests, procedures, or symptoms.';
            }
          }

          String policyInvalidReasonText = docMap?['policyInvalidReason']?.toString() ?? '';
          if (policyInvalidReasonText.isEmpty) {
            policyInvalidReasonText =
                'The uploaded policy document contains no recognizable insurance policy clauses, covered treatments, benefit rules, or insurance terms.';
          }

          final p = context.palette;
          final overallStyle = coverageStatusStyle(overallStatus.toString(), fallback: AppTone.warning);
          final verificationItems = _verificationItems(comparison);
          final majorTerms = asList(data['majorTerms']);

          return PushedShell(
            title: 'Coverage Summary',
            onBack: goBack,
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
                child: ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isDocumentInvalid) ...[
                        // ─── Invalid document: status, explanation and validation reasons ───
                        _VerdictCard(
                          tone: AppTone.danger,
                          icon: Icons.cancel_outlined,
                          eyebrow: 'ANALYSIS NOT COMPLETED',
                          title: invalidStatusTitle,
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              (data['summary'] != null &&
                                      data['summary'].toString().trim().isNotEmpty &&
                                      (data['summary'].toString().toLowerCase().contains('invalid') ||
                                          data['summary'].toString().toLowerCase().contains('self-entered') ||
                                          data['summary'].toString().toLowerCase().contains('uploaded')))
                                  ? data['summary'].toString()
                                  : invalidDisclaimer,
                              textAlign: TextAlign.start,
                              style: context.text.bodyMedium?.copyWith(color: p.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CardTitle(
                                title: 'Validation Failure Reasons',
                                icon: Icons.error_outline_rounded,
                                tone: AppTone.danger,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (!isPrescriptionValid) ...[
                                _ReasonBlock(
                                  icon: isManualRx ? Icons.edit_note_rounded : Icons.receipt_long_rounded,
                                  title: isManualRx ? 'Self-Entered Prescription Issue' : 'Uploaded Prescription Issue',
                                  text: rxInvalidReasonText,
                                ),
                                if (!isPolicyValid) const SizedBox(height: AppSpacing.sm),
                              ],
                              if (!isPolicyValid)
                                _ReasonBlock(
                                  icon: Icons.policy_outlined,
                                  title: 'Uploaded Policy Issue',
                                  text: policyInvalidReasonText,
                                ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // ─── 1. Overall verdict ───
                        _VerdictCard(
                          tone: overallStyle.tone,
                          icon: overallStyle.icon,
                          eyebrow: 'OVERALL COVERAGE RESULT',
                          title: overallStatus.toString(),
                          subtitle: comparison.isNotEmpty
                              ? 'Based on ${comparison.length} prescribed ${comparison.length == 1 ? 'item' : 'items'} '
                                    'assessed against your policy.'
                              : null,
                          children: [
                            if (coverage != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Divider(height: 1, color: p.border),
                              const SizedBox(height: AppSpacing.md),
                              _CoveragePercentBar(coverage: coverage, tone: overallStyle.tone),
                            ],
                          ],
                        ),

                        // ─── 2. Items whose coverage depends on a detail not yet known ───
                        if (verificationItems.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildVerificationCard(items: verificationItems),
                        ],

                        // ─── 3. Coverage breakdown ───
                        const SizedBox(height: AppSpacing.section),
                        const SectionHeader(
                          title: 'Coverage Breakdown',
                          subtitle: 'How the prescribed items were classified',
                        ),
                        if (manualReviewCount > 0) InfoBanner(tone: AppTone.warning, message: reviewMessage),
                        if (!allItemsNeedManualReview)
                          CoverageDonutChart(
                            coverageBreakdown: coverageBreakdown,
                            isPolicyValid: isPolicyValid,
                            isPrescriptionValid: isPrescriptionValid,
                          ),

                        // ─── 4. Decision for every item ───
                        if (comparison.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          SectionHeader(
                            title: 'Item-wise Coverage Decision',
                            subtitle: 'Result and reason for each prescribed item',
                            trailing: Text(
                              '${comparison.length} ${comparison.length == 1 ? 'item' : 'items'}',
                              style: context.text.labelMedium,
                            ),
                          ),
                          ...comparison.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _buildDecisionCard(item),
                            ),
                          ),
                        ],

                        // ─── 5. Major policy terms that make the analysis Not Covered ───
                        if (majorTerms.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildMajorTerms(terms: majorTerms),
                        ],
                        const SizedBox(height: AppSpacing.section),

                        // ─── 6. What was analysed ───
                        if (policyJson.isNotEmpty || prescriptionJson.isNotEmpty) ...[
                          const SectionHeader(
                            title: 'Documents Analysed',
                            subtitle: 'Details extracted from your policy and prescription',
                          ),
                        ],
                        if (policyJson.isNotEmpty) ...[
                          _buildInfoCard(
                            title: 'Policy Summary',
                            icon: Icons.shield_outlined,
                            tone: AppTone.brand,
                            items: [
                              _infoRow('Insurance Provider', policyJson['insuranceCompany']),
                              _infoRow('Policy Name', policyJson['policyName']),
                              _infoRow('Policy Number', policyJson['policyNumber']),
                              _infoRow('Policy Type', policyJson['policyType']),
                              _infoRow(
                                'Sum Insured',
                                policyJson['coverageAmount'] != null ? _money(policyJson['coverageAmount']) : null,
                              ),
                              _infoRow(
                                'Max Claim',
                                policyJson['maximumClaimAmount'] != null
                                    ? _money(policyJson['maximumClaimAmount'])
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Policy Continuity
                        if (data['policyContinuity'] is Map &&
                            (data['policyContinuity']['status'] ?? '').toString().isNotEmpty) ...[
                          PolicyContinuityCard(
                            continuity: Map<String, dynamic>.from(data['policyContinuity'] as Map),
                            isDark: context.isDark,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Prescription Summary
                        if (prescriptionJson.isNotEmpty) ...[
                          Builder(
                            builder: (context) {
                              final bool isManual =
                                  prescriptionJson['isManual'] == true ||
                                  data['isManualPrescription'] == true ||
                                  prescriptionJson['prescriptionSource'] == 'Self-entered Prescription' ||
                                  (prescriptionJson['manualText'] != null &&
                                      prescriptionJson['manualText'].toString().isNotEmpty);

                              String? cleanValue(dynamic v) {
                                if (v == null) return null;
                                if (v is List) {
                                  final filtered = v
                                      .map((e) => e.toString().trim())
                                      .where(
                                        (e) =>
                                            e.isNotEmpty &&
                                            e != '---' &&
                                            e.toLowerCase() != 'none' &&
                                            e.toLowerCase() != 'null' &&
                                            !e.toLowerCase().startsWith('unknown'),
                                      )
                                      .toList();
                                  return filtered.isNotEmpty ? filtered.join(', ') : null;
                                }
                                final str = v.toString().trim();
                                if (str.isEmpty ||
                                    str == '---' ||
                                    str == '[]' ||
                                    str == '[ ]' ||
                                    str.toLowerCase() == 'none' ||
                                    str.toLowerCase() == 'null' ||
                                    str.toLowerCase().startsWith('unknown')) {
                                  return null;
                                }
                                return str;
                              }

                              String? diag = cleanValue(prescriptionJson['diagnosis']);
                              if (diag == null) {
                                if (prescriptionJson['symptoms'] is List &&
                                    (prescriptionJson['symptoms'] as List).isNotEmpty) {
                                  diag = (prescriptionJson['symptoms'] as List)
                                      .map((e) => e.toString())
                                      .where((e) => e.isNotEmpty)
                                      .join(', ');
                                } else if (prescriptionJson['manualText'] != null) {
                                  diag = cleanValue(prescriptionJson['manualText']);
                                }
                              }

                              String? symptomsStr;
                              if (prescriptionJson['symptoms'] is List &&
                                  (prescriptionJson['symptoms'] as List).isNotEmpty) {
                                symptomsStr = (prescriptionJson['symptoms'] as List)
                                    .map((e) => e.toString())
                                    .where((e) => e.isNotEmpty)
                                    .join(', ');
                              }

                              return _buildInfoCard(
                                title: 'Prescription Summary',
                                icon: isManual ? Icons.edit_note_rounded : Icons.medical_information_outlined,
                                tone: AppTone.verify,
                                trailing: isManual
                                    ? const StatusBadge(label: 'Self-entered', tone: AppTone.info, dense: true)
                                    : null,
                                items: [
                                  _infoRow('Patient Name', cleanValue(prescriptionJson['patientName'])),
                                  _infoRow('Hospital', cleanValue(prescriptionJson['hospitalName'])),
                                  _infoRow('Doctor', cleanValue(prescriptionJson['doctorName'])),
                                  _infoRow('Primary Diagnosis', diag),
                                  if (symptomsStr != null && symptomsStr != diag)
                                    _infoRow('Reported Symptoms', symptomsStr),
                                  // A self-entered check has no admission details to show.
                                  if (!isManual)
                                    _infoRow(
                                      'Hospitalization',
                                      prescriptionJson['hospitalizationRequired'] == true
                                          ? 'Required'
                                          : prescriptionJson['hospitalizationRequired'] == false
                                          ? 'Not Required'
                                          : null,
                                    ),
                                  Builder(
                                    builder: (_) {
                                      // The extractor stores it as estimatedCost; older reports used estimatedTreatmentCost.
                                      final est =
                                          prescriptionJson['estimatedCost'] ??
                                          prescriptionJson['estimatedTreatmentCost'];
                                      return _infoRow(
                                            'Est. Cost',
                                            est != null && est.toString() != '0' ? _money(est) : null,
                                          ) ??
                                          const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ─── 7. Clarification answers given during the analysis ───
                        if (clarificationQA.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          const SectionHeader(
                            title: 'Clarification Q&A',
                            subtitle: 'Your answers that were used in this analysis',
                          ),
                          ...clarificationQA.asMap().entries.map((entry) => _buildQaCard(entry.key, entry.value)),
                          const SizedBox(height: AppSpacing.xs),
                        ],

                        // ─── Disclaimer ───
                        const SizedBox(height: AppSpacing.xs),
                        InfoBanner(
                          tone: AppTone.neutral,
                          icon: Icons.info_outline_rounded,
                          child: RichText(
                            textAlign: TextAlign.start,
                            text: TextSpan(
                              style: context.text.bodySmall?.copyWith(color: p.textSecondary, height: 1.5),
                              children: const [
                                TextSpan(
                                  text: 'Disclaimer: ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text:
                                      'This is a system-generated reference. It does not guarantee approval. Final decisions rest with your insurance provider.',
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (processingTime is num && processingTime > 0) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: p.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                'Analysis completed in ${(processingTime / 1000).toStringAsFixed(1)}s',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ],

                      const SizedBox(height: AppSpacing.xl),

                      // ─── Back to Dashboard ───
                      PrimaryButton(
                        label: 'Back to Dashboard',
                        icon: Icons.home_outlined,
                        onPressed: () {
                          ref.invalidate(dashboardStatsProvider);
                          context.go('/dashboard');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Helpers: counts and statuses ───
  bool _isNeedsVerification(dynamic item) {
    if (item is! Map) return false;
    return (item['coverageStatus'] ?? item['status'] ?? '').toString() == _needsVerification;
  }

  List<Map> _verificationItems(List<dynamic> comparison) => comparison.where(_isNeedsVerification).cast<Map>().toList();

  /// Status text for a comparison row, and its colour/icon. Rows without a
  /// recognised status fall back to the backend's `isCovered` flag.
  ({String label, CoverageStatusStyle style}) _itemStatus(dynamic item, {String fallbackLabel = ''}) {
    final map = item is Map ? item : const {};
    final label = (map['status'] ?? map['coverageStatus'] ?? fallbackLabel).toString();
    final style = coverageStatusStyle(label, fallback: map['isCovered'] == true ? AppTone.success : AppTone.danger);
    return (label: label, style: style);
  }

  /// Formats an amount as rupees with Indian digit grouping; leaves non-numeric text as-is.
  String _money(dynamic value) {
    final n = value is num ? value : num.tryParse(value.toString().replaceAll(',', '').trim());
    if (n == null) return '₹$value';
    final fmt = NumberFormat.decimalPattern('en_IN');
    return '₹${fmt.format(n)}';
  }

  // ─── Decision card: item + result, reason, money, then the policy wording ───
  Widget _buildDecisionCard(dynamic rawItem) {
    return Builder(
      builder: (context) {
        final p = context.palette;
        final item = rawItem is Map ? rawItem : const {};
        final status = (item['status'] ?? item['coverageStatus'] ?? 'Not Covered').toString();
        final style = _itemStatus(item, fallbackLabel: 'Not Covered').style;

        final reason = (item['explanation'] ?? item['reason'] ?? item['coverageStatusReason'] ?? '').toString().trim();
        final rawEvidence = (item['policyEvidence'] ?? '').toString().trim();
        final policyEvidence = rawEvidence == "No matching policy clause found." ? '' : rawEvidence;
        final financialDecision = (item['financialDecision'] ?? '').toString().trim();
        final policyClauses = asList(item['policyClauses']);
        final cost = item['cost'];
        final hasCost = cost != null && cost != 0 && cost.toString().trim().isNotEmpty;
        final wordingCount = (policyEvidence.isNotEmpty ? 1 : 0) + policyClauses.length;

        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Item + result
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(icon: style.icon, tone: style.tone, size: 40),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['item'] ?? 'Prescribed Treatment / Diagnosis').toString(),
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xxs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusBadge(label: status, tone: style.tone, icon: style.icon, dense: true),
                              if (hasCost) Text('Est. cost ${_money(cost)}', style: context.text.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (reason.isNotEmpty) ...[
                      const _BlockLabel('Status Reason'),
                      const SizedBox(height: AppSpacing.xs),
                      _PointList(
                        text: reason,
                        style: context.text.bodyMedium?.copyWith(color: p.textPrimary, height: 1.5),
                      ),
                    ],
                    if (financialDecision.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _DetailPanel(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Financial Status',
                        tone: AppTone.neutral,
                        child: Text(
                          financialDecision,
                          textAlign: TextAlign.start,
                          style: context.text.bodySmall?.copyWith(color: p.textPrimary, height: 1.45),
                        ),
                      ),
                    ],
                    if (reason.isEmpty && financialDecision.isEmpty && wordingCount == 0)
                      Text('No further details were provided for this item.', style: context.text.bodySmall),
                  ],
                ),
              ),
              if (wordingCount > 0)
                _ExpandableSection(
                  title: 'Policy wording used',
                  count: wordingCount,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (policyEvidence.isNotEmpty)
                        _DetailPanel(
                          icon: Icons.gavel_rounded,
                          label: 'Policy Evidence',
                          tone: AppTone.info,
                          child: _PointList(
                            text: policyEvidence,
                            spacing: AppSpacing.xs,
                            style: context.text.bodySmall?.copyWith(color: p.textPrimary, height: 1.45),
                          ),
                        ),
                      if (policyClauses.isNotEmpty) ...[
                        if (policyEvidence.isNotEmpty) const SizedBox(height: AppSpacing.sm),
                        _buildPolicyClauses(clauses: policyClauses),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Needs Verification: what must be confirmed before coverage is known ───
  Widget _buildVerificationCard({required List<Map> items}) {
    return Builder(
      builder: (context) {
        final p = context.palette;
        final t = p.verify;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: t.fg, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _needsVerification,
                          style: context.text.titleMedium?.copyWith(color: t.fg, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Coverage for these items depends on a detail that must be confirmed.',
                          style: context.text.bodySmall?.copyWith(color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              for (int i = 0; i < items.length; i++) ...[
                const SizedBox(height: AppSpacing.sm),
                Builder(
                  builder: (context) {
                    final item = items[i];
                    final name = (item['item'] ?? 'Prescribed Treatment').toString();
                    String condition = (item['verificationCondition'] ?? '').toString().trim();
                    if (condition.isEmpty) {
                      condition = (item['coverageStatusReason'] ?? item['explanation'] ?? item['reason'] ?? '')
                          .toString()
                          .trim();
                    }
                    final clause = (item['verificationClause'] ?? '').toString().trim();

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: t.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: context.text.titleSmall),
                          if (condition.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              condition,
                              textAlign: TextAlign.start,
                              style: context.text.bodyMedium?.copyWith(color: p.textPrimary),
                            ),
                          ],
                          if (clause.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            RichText(
                              text: TextSpan(
                                style: context.text.bodySmall?.copyWith(color: t.fg),
                                children: [
                                  const TextSpan(
                                    text: 'Clause: ',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(text: clause),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── Info card (Policy / Prescription summary) ───
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required AppTone tone,
    required List<Widget?> items,
    Widget? trailing,
  }) {
    final validItems = items.whereType<Widget>().toList();
    if (validItems.isEmpty) return const SizedBox.shrink();

    return Builder(
      builder: (context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle(title: title, icon: icon, tone: tone, trailing: trailing),
            const SizedBox(height: AppSpacing.sm),
            Divider(color: context.palette.border),
            const SizedBox(height: AppSpacing.xxs),
            ...validItems,
          ],
        ),
      ),
    );
  }

  // ─── Info row (returns null if value is missing so row is hidden) ───
  Widget? _infoRow(String label, dynamic value) {
    if (value == null) return null;
    String displayVal = '';
    if (value is List) {
      final filtered = value
          .map((e) => e.toString().trim())
          .where(
            (e) =>
                e.isNotEmpty &&
                e != '---' &&
                e.toLowerCase() != 'none' &&
                e.toLowerCase() != 'null' &&
                !e.toLowerCase().startsWith('unknown'),
          )
          .toList();
      if (filtered.isNotEmpty) displayVal = filtered.join(', ');
    } else {
      final str = value.toString().trim();
      if (str.isNotEmpty &&
          str != '---' &&
          str != '[]' &&
          str != '[ ]' &&
          str.toLowerCase() != 'none' &&
          str.toLowerCase() != 'null' &&
          !str.toLowerCase().startsWith('unknown')) {
        displayVal = str;
      }
    }
    if (displayVal.isEmpty) return null;
    return KeyValueRow(label: label, value: displayVal, labelWidth: SummaryInfoRow.labelWidth);
  }

  // ─── Clarification Q&A card ───
  Widget _buildQaCard(int idx, dynamic raw) {
    final qa = raw is Map ? raw : const {};
    final title = (qa['Title'] ?? qa['title'] ?? '').toString().trim();
    final question = (qa['Question'] ?? qa['question'] ?? '').toString().trim();
    final answer = (qa['User_Answer'] ?? qa['userAnswer'] ?? qa['answer'] ?? '').toString().trim();
    if (question.isEmpty && title.isEmpty) return const SizedBox.shrink();

    return Builder(
      builder: (context) {
        final p = context.palette;
        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
                child: Text(
                  '${idx + 1}',
                  style: context.text.labelMedium?.copyWith(color: p.accent, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) Text(title, style: context.text.labelMedium?.copyWith(color: p.accent)),
                    if (question.isNotEmpty) ...[
                      if (title.isNotEmpty) const SizedBox(height: 2),
                      Text(
                        question,
                        textAlign: TextAlign.start,
                        style: context.text.bodyMedium?.copyWith(color: p.textPrimary),
                      ),
                    ],
                    if (answer.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
                        decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: AppRadius.smAll),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.person_outline_rounded, size: 16, color: p.textTertiary),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                answer,
                                style: context.text.bodyMedium?.copyWith(
                                  color: p.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Exact policy passages behind one item's decision ───
  Widget _buildPolicyClauses({required List<dynamic> clauses}) {
    AppTone effectTone(String effect) {
      switch (effect) {
        case 'Excludes':
          return AppTone.danger;
        case 'Waiting Period':
        case 'Condition':
        case 'Limit':
          return AppTone.warning;
        case 'Covers':
          return AppTone.success;
        default:
          return AppTone.info;
      }
    }

    return Builder(
      builder: (context) {
        final p = context.palette;
        return _DetailPanel(
          icon: Icons.menu_book_outlined,
          label: 'Policy Clauses Considered',
          tone: AppTone.neutral,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < clauses.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                Builder(
                  builder: (context) {
                    final clause = clauses[i] is Map ? clauses[i] as Map : const {};
                    final effect = (clause['effect'] ?? '').toString();
                    final tone = effectTone(effect);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                (clause['section'] ?? '').toString(),
                                style: context.text.labelMedium?.copyWith(color: p.textPrimary),
                              ),
                            ),
                            if (effect.isNotEmpty) ...[
                              const SizedBox(width: AppSpacing.xs),
                              StatusBadge(label: effect, tone: tone, dense: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: p.tone(tone).fg, width: 2)),
                          ),
                          child: Text(
                            '"${clause['quote'] ?? ''}"',
                            textAlign: TextAlign.start,
                            style: context.text.bodySmall?.copyWith(color: p.textPrimary, fontStyle: FontStyle.italic),
                          ),
                        ),
                        if ((clause['explanation'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            clause['explanation'].toString(),
                            textAlign: TextAlign.start,
                            style: context.text.bodySmall,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── Policy terms that make the overall analysis Not Covered ───
  Widget _buildMajorTerms({required List<dynamic> terms}) {
    return Builder(
      builder: (context) {
        final p = context.palette;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardTitle(
                title: 'Major Policy Terms – Not Covered',
                subtitle: 'Policy terms that led to this result',
                icon: Icons.gavel_rounded,
                tone: AppTone.danger,
              ),
              for (int i = 0; i < terms.length; i++) ...[
                const SizedBox(height: AppSpacing.md),
                if (i > 0) ...[Divider(height: 1, color: p.border), const SizedBox(height: AppSpacing.md)],
                Builder(
                  builder: (context) {
                    final term = terms[i] is Map ? terms[i] as Map : const {};
                    final applies = asList(term['items']);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text((term['title'] ?? '').toString(), style: context.text.titleSmall),
                        if ((term['quote'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm,
                              AppSpacing.xs,
                              AppSpacing.sm,
                              AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: p.surfaceMuted,
                              border: Border(left: BorderSide(color: p.danger.fg, width: 3)),
                            ),
                            child: Text(
                              '"${term['quote']}"',
                              textAlign: TextAlign.start,
                              style: context.text.bodySmall?.copyWith(
                                color: p.textPrimary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                        if ((term['explanation'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            term['explanation'].toString(),
                            textAlign: TextAlign.start,
                            style: context.text.bodyMedium,
                          ),
                        ],
                        if (applies.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Applies to: ',
                                  style: context.text.labelMedium?.copyWith(color: p.textTertiary),
                                ),
                                TextSpan(
                                  text: applies.join(', '),
                                  style: context.text.labelMedium?.copyWith(color: p.danger.fg),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Presentation-only building blocks for the coverage report
// ─────────────────────────────────────────────────────────────────────────────

/// Headline card holding the overall result (white card, status-coloured accent bar).
class _VerdictCard extends StatelessWidget {
  final AppTone tone;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _VerdictCard({
    required this.tone,
    required this.icon,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = p.tone(tone);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: p.border),
        boxShadow: p.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: t.fg),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(eyebrow, style: context.text.labelSmall),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
                      child: Icon(icon, color: t.fg, size: 26),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(title, style: context.text.headlineSmall?.copyWith(color: t.fg, fontSize: 22)),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(subtitle!, style: context.text.bodyMedium),
                ],
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How much of the claim the analysis expects to be covered.
///
/// Uses the money figures when the prescription gives a cost estimate and the
/// analysis estimated the insurer's share; otherwise the share of assessed
/// items that are covered (fully or partly). Items still under manual review
/// or needing verification are left out, and nothing is shown if none remain.
class _CoveragePercent {
  const _CoveragePercent(this.percent, this.basis);

  final double percent;
  final String basis;

  static _CoveragePercent? from(Map<String, dynamic> data) {
    num? amount(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString().replaceAll(',', ''));
    final fs = data['financialSummary'];
    if (fs is Map) {
      final total = amount(fs['estimatedTotalCost']);
      final insurer = amount(fs['estimatedPayableAmount']);
      if (total != null && total > 0 && insurer != null && insurer >= 0) {
        return _CoveragePercent((insurer / total * 100).clamp(0, 100).toDouble(), 'Share of the estimated bill the insurer may pay');
      }
    }
    var assessed = 0;
    var covered = 0;
    for (final item in asList(data['comparison'])) {
      if (item is! Map) continue;
      final status = (item['coverageStatus'] ?? item['status'] ?? '').toString().trim().toLowerCase();
      if (status.contains('manual') || status.contains('verif') || status.isEmpty) continue;
      assessed++;
      if (status == 'covered' || status == 'partially covered') covered++;
    }
    if (assessed == 0) return null;
    return _CoveragePercent(covered / assessed * 100, 'Share of assessed items that are covered');
  }
}

class _CoveragePercentBar extends StatelessWidget {
  final _CoveragePercent coverage;
  final AppTone tone;

  const _CoveragePercentBar({required this.coverage, required this.tone});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = p.tone(tone);
    final value = coverage.percent;
    final text = value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coverage', style: context.text.titleSmall),
                  Text(coverage.basis, style: context.text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('$text%', style: context.text.headlineSmall?.copyWith(color: t.fg, fontSize: 24)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.pillAll,
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0, 1).toDouble(),
            minHeight: 8,
            color: t.fg,
            backgroundColor: p.surface,
          ),
        ),
      ],
    );
  }
}

/// Collapsible footer section of an item card ("Policy wording used").
class _ExpandableSection extends StatefulWidget {
  final String title;
  final int count;
  final Widget child;

  const _ExpandableSection({required this.title, required this.count, required this.child});

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: p.border),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.menu_book_outlined, size: 18, color: p.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${widget.title} (${widget.count})',
                    style: context.text.labelLarge?.copyWith(fontSize: 13.5, color: p.primary),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, color: p.primary),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Renders explanatory text as a bulleted list, one point per sentence.
/// A single sentence is shown as plain text (a lone bullet looks odd).
class _PointList extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double spacing;

  const _PointList({required this.text, this.style, this.spacing = AppSpacing.xs + 2});

  @override
  Widget build(BuildContext context) {
    final points = splitIntoPoints(text);
    if (points.length <= 1) {
      return Text(points.isEmpty ? text : points.first, textAlign: TextAlign.start, style: style);
    }
    final fontSize = style?.fontSize ?? 14;
    final lineHeight = fontSize * (style?.height ?? 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < points.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : spacing),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dot centred on the first line of text.
                SizedBox(
                  width: 14,
                  height: lineHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: context.palette.primary, shape: BoxShape.circle),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(points[i], textAlign: TextAlign.start, style: style),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small uppercase label above a block of text.
class _BlockLabel extends StatelessWidget {
  final String text;

  const _BlockLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: context.text.labelSmall);
  }
}

/// Tinted panel with an icon + label header, used for supporting evidence.
class _DetailPanel extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppTone tone;
  final Widget child;

  const _DetailPanel({required this.icon, required this.label, required this.tone, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = p.tone(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: tone == AppTone.neutral ? p.surfaceMuted : t.bg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: tone == AppTone.neutral ? p.border : t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tone == AppTone.neutral ? p.textSecondary : t.fg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: context.text.labelMedium?.copyWith(
                    color: tone == AppTone.neutral ? p.textPrimary : t.fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// One validation failure reason on the invalid-document view.
class _ReasonBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _ReasonBlock({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = p.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: t.fg, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleSmall?.copyWith(color: t.fg, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            text,
            textAlign: TextAlign.start,
            style: context.text.bodyMedium?.copyWith(color: p.textPrimary),
          ),
        ],
      ),
    );
  }
}
