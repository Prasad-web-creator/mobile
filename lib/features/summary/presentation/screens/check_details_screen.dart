import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/localization/translation_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_choices.dart';
import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/app_status.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/summary/data/check_details_repository.dart';
import 'package:claimsupport/features/summary/presentation/screens/coverage_check_report.dart';

final checkDetailsRepositoryProvider = Provider(
  (ref) => CheckDetailsRepository(),
);

final checkDetailsProvider = FutureProvider.autoDispose
    .family<AnalysisReportGroup, String>(
      (ref, groupId) =>
          ref.watch(checkDetailsRepositoryProvider).loadGroup(groupId),
    );

final _treatmentDetails = FutureProvider.autoDispose
    .family<CheckDocumentDetails, AnalysisReportGroup>(
      (ref, group) =>
          ref.watch(checkDetailsRepositoryProvider).loadTreatment(group),
    );

final _policyDetails = FutureProvider.autoDispose
    .family<CheckDocumentDetails, PolicyReportRow>(
      (ref, policy) =>
          ref.watch(checkDetailsRepositoryProvider).loadPolicy(policy),
    );

final _treatmentFile = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(checkDetailsRepositoryProvider).loadFile(id),
);

const _shareChannel = MethodChannel('policy_pal/share');

class CheckDetailsScreen extends ConsumerStatefulWidget {
  const CheckDetailsScreen({
    super.key,
    required this.groupId,
    this.initialGroup,
  });

  final String groupId;
  final AnalysisReportGroup? initialGroup;

  @override
  ConsumerState<CheckDetailsScreen> createState() => _CheckDetailsScreenState();
}

class _CheckDetailsScreenState extends ConsumerState<CheckDetailsScreen> {
  int? _selectedPolicyIndex;

  @override
  void didUpdateWidget(covariant CheckDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) _selectedPolicyIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(checkDetailsProvider(widget.groupId));
    final initial = widget.initialGroup;
    final group =
        details.value ?? (initial?.groupId == widget.groupId ? initial : null);
    final summary = group == null ? null : CheckSummary.fromGroup(group);
    final policies = group?.policyReports ?? const <PolicyReportRow>[];
    if (group != null &&
        policies.isNotEmpty &&
        (policies.any((row) => row.hasReport) ||
            policies.length == 1 && group.reportIds.length == 1)) {
      return CoverageCheckReport(
        key: ValueKey(group.groupId),
        group: group,
        loadReport: ref.watch(checkDetailsRepositoryProvider).loadReport,
        loadPolicyProductName: ref
            .watch(checkDetailsRepositoryProvider)
            .loadPolicyProductName,
        onOpenTreatment: (title, subtitle) => _openDocument(
          context,
          title: title,
          subtitle: subtitle,
          artwork: AppIllustrationKind.prescription,
          details: _treatmentDetails(group),
        ),
        onOpenPolicy: (policy, title, subtitle) => _openDocument(
          context,
          title: title,
          subtitle: subtitle,
          artwork: AppIllustrationKind.policy,
          details: _policyDetails(policy),
        ),
        onBack: () => context.canPop() ? context.pop() : context.go('/reports'),
      );
    }
    final bestIndex = group == null || group.bestPolicyId.isEmpty
        ? -1
        : policies.indexWhere(
            (policy) => policy.policyId == group.bestPolicyId,
          );
    final chosenIndex = _selectedPolicyIndex ?? (bestIndex < 0 ? 0 : bestIndex);
    final selectedIndex = chosenIndex < policies.length ? chosenIndex : 0;
    final selected = policies.elementAtOrNull(selectedIndex);
    final status = selected == null
        ? null
        : _statusOption(context, selected, selectedIndex == bestIndex);
    final selectedReportId = selected?.reportId.trim() ?? '';
    final singleReportId =
        group != null &&
            group.policyCount <= 1 &&
            policies.length <= 1 &&
            group.reportIds.length == 1
        ? group.reportIds.single.trim()
        : '';
    final reportId = selectedReportId.isNotEmpty
        ? selectedReportId
        : singleReportId;
    void retry() => ref.invalidate(checkDetailsProvider(widget.groupId));

    return PushedShell(
      title:
          summary?.displayTreatment(context.l10n) ??
          context.l10n.analysisCheckDetails,
      onBack: () => context.canPop() ? context.pop() : context.go('/reports'),
      action: summary == null
          ? null
          : AppIconButton(
              icon: AppIcons.share,
              label: context.l10n.analysisShare,
              onPressed: () => _share(context, summary, status),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DsSpace.screenPadding,
          DsSpace.s0,
          DsSpace.screenPadding,
          DsSpace.sectionGap,
        ),
        children: [
          if (group == null) ...[
            if (details.hasError)
              AppInlineBanner(
                kind: AppInlineBannerKind.error,
                message: details.error is CheckNotFoundException
                    ? context.l10n.analysisCheckNotFound
                    : context.l10n.analysisLoadCheckFailed,
                onRetry: retry,
              )
            else
              const AppSkeleton(kind: AppSkeletonKind.card),
          ] else ...[
            if (details.hasError) ...[
              AppInlineBanner(
                kind: AppInlineBannerKind.offline,
                message: context.l10n.analysisShowingSavedCheck,
                onRetry: retry,
              ),
              const SizedBox(height: DsSpace.gridGap),
            ],
            _metadata(context, summary!),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedSwitcher(
                duration: DsMotion.base,
                child: AppStatusPill(
                  key: ValueKey((
                    status?.kind ?? summary.statusKind,
                    status?.statusLabel ?? summary.statusLabel,
                  )),
                  kind: status?.kind ?? summary.statusKind,
                  label: status?.statusLabel ?? summary.statusLabel,
                ),
              ),
            ),
            if (policies.length > 1) ...[
              const SizedBox(height: DsSpace.sectionGap),
              AppPolicySwitcher(
                policies: [
                  for (final (index, policy) in policies.indexed)
                    _statusOption(context, policy, index == bestIndex),
                ],
                selectedIndex: selectedIndex,
                onChanged: (index) =>
                    setState(() => _selectedPolicyIndex = index),
              ),
            ],
            if (group.status == 'waiting_for_user' ||
                summary.statusKind == CheckStatusKind.checking) ...[
              const SizedBox(height: DsSpace.gridGap),
              AppLink(
                label: group.status == 'waiting_for_user'
                    ? context.l10n.analysisAnswerQuestions
                    : context.l10n.analysisViewProgress,
                trailing: AppIcons.caretRight,
                onPressed: () {
                  final id = group.groupId;
                  context.push(
                    group.isDurableJob
                        ? '/check/processing/${Uri.encodeComponent(id)}'
                        : Uri(
                            path: '/analysis-multi',
                            queryParameters: {'session': id},
                          ).toString(),
                  );
                },
              ),
            ],
            if (reportId.isNotEmpty) ...[
              const SizedBox(height: DsSpace.sectionGap),
              AppButton(
                label: context.l10n.analysisViewCoverageReport,
                icon: AppIcons.caretRight,
                onPressed: () =>
                    context.push('/summary/${Uri.encodeComponent(reportId)}'),
              ),
            ],
            const SizedBox(height: DsSpace.sectionGap),
            AnimatedSwitcher(
              duration: DsMotion.base,
              child: Column(
                key: ValueKey(selectedIndex),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.gridGap,
                children: [
                  if (selected != null && selected.reasons.isNotEmpty)
                    _Reasons(reasons: selected.reasons),
                  if (group.prescriptionId.isNotEmpty ||
                      summary.treatment != 'Prescription' ||
                      summary.patientName.isNotEmpty ||
                      group.visitDate.trim().isNotEmpty)
                    AppDocumentRow(
                      type: DocumentCardType.prescription,
                      title: context.l10n.analysisTreatmentDocument,
                      meta: summary.treatment == 'Prescription'
                          ? ''
                          : summary.displayTreatment(context.l10n),
                      onTap: () => _openDocument(
                        context,
                        title: context.l10n.analysisTreatmentDocument,
                        details: _treatmentDetails(group),
                      ),
                    ),
                  if (selected != null && _hasPolicy(selected))
                    AppDocumentRow(
                      type: DocumentCardType.policy,
                      title: context.l10n.analysisPolicy,
                      meta: selected.displayName == 'Policy'
                          ? ''
                          : selected.displayName,
                      onTap: () => _openDocument(
                        context,
                        title: context.l10n.analysisPolicy,
                        details: _policyDetails(selected),
                      ),
                    ),
                  Text(
                    context.l10n.analysisCheckDisclaimer,
                    style: AppTextStyles.label.copyWith(
                      color: context.colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _metadata(BuildContext context, CheckSummary summary) {
    final parts = [
      if (summary.patientName.isNotEmpty)
        context.l10n.analysisForPatient(summary.patientName),
      if (summary.dateLabel.isNotEmpty) summary.dateLabel,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DsSpace.s12),
      child: Text(
        parts.join(' · '),
        style: AppTextStyles.label.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }

  static bool _hasPolicy(PolicyReportRow policy) =>
      policy.policyId.isNotEmpty ||
      policy.policyName.trim().isNotEmpty ||
      policy.insuranceCompany.trim().isNotEmpty ||
      policy.policyNumber.trim().isNotEmpty ||
      policy.policyEndDate.trim().isNotEmpty;

  static AppPolicyOption _statusOption(
    BuildContext context,
    PolicyReportRow policy,
    bool best,
  ) {
    final raw = policy.overallStatus.trim();
    final (kind, label) = switch (policy.status) {
      'pending' || 'queued' || 'extracting' || 'analyzing' || 'reanalyzing' => (
        CheckStatusKind.checking,
        context.l10n.analysisChecking,
      ),
      'waiting_for_user' => (
        CheckStatusKind.other,
        context.l10n.analysisNeedsInput,
      ),
      'failed' => (
        CheckStatusKind.failed,
        policy.failedAtStage.contains('extract')
            ? context.l10n.analysisCouldNotRead
            : context.l10n.analysisCheckFailed,
      ),
      _ when raw.isNotEmpty => (CheckSummary.statusKindFor(raw), raw),
      'manual_review_required' => (
        CheckStatusKind.other,
        context.l10n.analysisNeedsVerification,
      ),
      'invalid' => (CheckStatusKind.other, context.l10n.analysisInvalidPolicy),
      _ => (CheckStatusKind.other, context.l10n.analysisResultUnavailable),
    };
    return AppPolicyOption(
      label: policy.displayName == 'Policy'
          ? context.l10n.sharedPolicy
          : policy.displayName,
      kind: kind,
      statusLabel: kind.coverageLabel ?? label,
      best: best,
    );
  }

  static Future<void> _share(
    BuildContext context,
    CheckSummary summary,
    AppPolicyOption? policy,
  ) async {
    final text = [
      summary.displayTreatment(context.l10n),
      if (policy != null) policy.label,
      localizedCheckStatus(
        context.l10n,
        policy?.statusLabel ?? summary.statusLabel,
      ),
      context.l10n.analysisCheckDisclaimer,
    ].join('\n');
    try {
      await _shareChannel.invokeMethod<void>('shareText', text);
    } on MissingPluginException {
      if (!context.mounted) return;
      await AppSheet.show<void>(
        context: context,
        title: context.l10n.analysisShareCheck,
        bodyBuilder: (sheetContext) => AppButton(
          label: context.l10n.analysisCopyCheckSummary,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
        ),
      );
    } on PlatformException {
      if (!context.mounted) return;
      await AppSheet.show<void>(
        context: context,
        title: context.l10n.analysisShareCheck,
        bodyBuilder: (context) => AppInlineBanner(
          kind: AppInlineBannerKind.error,
          message: context.l10n.analysisSharingUnavailable,
        ),
      );
    }
  }

  static void _openDocument(
    BuildContext context, {
    required String title,
    required FutureProvider<CheckDocumentDetails> details,
    String? subtitle,
    AppIllustrationKind? artwork,
  }) {
    AppSheet.show<void>(
      context: context,
      title: title,
      subtitle: subtitle,
      artwork: artwork,
      showClose: true,
      footerBuilder: (_) => Consumer(
        builder: (sheetContext, ref, _) {
          final data = ref.watch(details).value;
          final fileId = data?.fileId;
          if (fileId == null) return const SizedBox.shrink();
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: sheetContext.colors.borderDivider),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: DsSpace.s12),
              child: AppButton(
                label: context.l10n.analysisViewDocument,
                style: AppButtonStyle.secondary,
                onPressed: () {
                  if (data?.mimeType?.startsWith('image/') == true) {
                    AppSheet.show<void>(
                      context: sheetContext,
                      title: title,
                      showClose: true,
                      bodyBuilder: (_) =>
                          _DocumentPreview(fileId: fileId, isPdf: false),
                    );
                  } else {
                    Navigator.pop(sheetContext);
                    if (context.mounted) {
                      context.push(
                        Uri(
                          path: '/view-pdf/${Uri.encodeComponent(fileId)}',
                          queryParameters: {'title': title},
                        ).toString(),
                      );
                    }
                  }
                },
              ),
            ),
          );
        },
      ),
      bodyBuilder: (sheetContext) => Consumer(
        builder: (sheetContext, ref, _) => ref
            .watch(details)
            .when(
              loading: () => const AppSkeleton(kind: AppSkeletonKind.row),
              error: (_, _) => AppInlineBanner(
                kind: AppInlineBannerKind.error,
                message: context.l10n.analysisLoadDetailsFailed,
                onRetry: () => ref.invalidate(details),
              ),
              data: (data) {
                final fileId = data.fileId;
                final mimeType = data.mimeType ?? '';
                if (!data.hasData) {
                  return Text(
                    context.l10n.analysisNoAdditionalDetails,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: sheetContext.colors.textSecondary,
                    ),
                  );
                }
                return AppSheetList(
                  rows: [
                    if (artwork == null &&
                        fileId != null &&
                        (mimeType.startsWith('image/') ||
                            mimeType == 'application/pdf'))
                      _DocumentPreview(
                        fileId: fileId,
                        isPdf: mimeType == 'application/pdf',
                      ),
                    for (final (label, value) in data.displayFields(
                      sheetContext.l10n,
                    ))
                      AppSheetKeyValue(
                        label: label,
                        value: value,
                        monospace:
                            label == sheetContext.l10n.sharedPolicyNumber,
                      ),
                    if (data.displayList(sheetContext.l10n) case (
                      final label,
                      final values,
                    ))
                      AppSheetFieldList(label: label, values: values),
                  ],
                );
              },
            ),
      ),
    );
  }
}

class _DocumentPreview extends ConsumerWidget {
  const _DocumentPreview({required this.fileId, required this.isPdf});

  final String fileId;
  final bool isPdf;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_treatmentFile(fileId))
      .when(
        loading: () => const AppSkeleton(kind: AppSkeletonKind.card),
        error: (_, _) => AppInlineBanner(
          kind: AppInlineBannerKind.error,
          message: context.l10n.analysisLoadPreviewFailed,
          onRetry: () => ref.invalidate(_treatmentFile(fileId)),
        ),
        data: (bytes) => ClipRSuperellipse(
          borderRadius: const BorderRadius.all(
            Radius.circular(DsShape.radiusLg),
          ),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: isPdf
                ? SfPdfViewer.memory(
                    bytes,
                    pageLayoutMode: PdfPageLayoutMode.single,
                    scrollDirection: PdfScrollDirection.horizontal,
                    canShowScrollHead: false,
                    canShowScrollStatus: false,
                    canShowPaginationDialog: false,
                  )
                : Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    semanticLabel: context.l10n.analysisTreatmentImage,
                    errorBuilder: (_, _, _) => AppInlineBanner(
                      kind: AppInlineBannerKind.error,
                      message: context.l10n.analysisReadImageFailed,
                    ),
                  ),
          ),
        ),
      );
}

class _Reasons extends StatelessWidget {
  const _Reasons({required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.label.copyWith(
      color: context.colors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.l10n.analysisWhyResult,
          onSeeAll: reasons.length <= 3
              ? null
              : () => AppSheet.show<void>(
                  context: context,
                  title: context.l10n.analysisWhyResult,
                  bodyBuilder: (_) => AppSheetList(
                    rows: [
                      for (final reason in reasons) Text(reason, style: style),
                    ],
                  ),
                ),
        ),
        for (final reason in reasons.take(3))
          Text(
            reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
      ],
    );
  }
}
