import 'dart:math' as math;

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/utils/activity_timestamp.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/core/design/widgets/app_pressable.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/app_status.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/summary/data/policy_evidence.dart';
import 'package:claimsupport/features/summary/presentation/widgets/policy_continuity_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CoverageCheckReport extends StatefulWidget {
  const CoverageCheckReport({
    super.key,
    required this.group,
    required this.loadReport,
    required this.loadPolicyProductName,
    required this.onBack,
    this.onOpenTreatment,
    this.onOpenPolicy,
  });

  final AnalysisReportGroup group;
  final Future<Map<String, dynamic>?> Function(String) loadReport;
  final Future<String?> Function(String) loadPolicyProductName;
  final VoidCallback onBack;
  final void Function(String title, String subtitle)? onOpenTreatment;
  final void Function(PolicyReportRow policy, String title, String subtitle)? onOpenPolicy;

  @override
  State<CoverageCheckReport> createState() => _CoverageCheckReportState();
}

class _CoverageCheckReportState extends State<CoverageCheckReport> {
  final _tabs = ScrollController();
  final _reports = <String, Future<Map<String, dynamic>?>>{};
  final _names = <(String, String), Future<String?>>{};
  final _evidence = <String, PolicyEvidence>{};
  String? _policyKey;
  int? _expanded = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  (CheckStatusKind, String) _status(PolicyReportRow row, [String? reportStatus]) =>
      CheckSummary.resultForPolicy(row, overallStatus: reportStatus);

  String _reportId(PolicyReportRow row) => row.hasReport
      ? row.reportId
      : widget.group.policyReports.length == 1 && widget.group.reportIds.length == 1
      ? widget.group.reportIds.single
      : '';

  Future<Map<String, dynamic>?> _report(String id) => _reports.putIfAbsent(id, () => widget.loadReport(id));

  Future<String?> _resolveName(PolicyReportRow row, String reportId) async {
    if (reportId.isNotEmpty) {
      try {
        final report = await _report(reportId);
        final policy = report?['policyJson'];
        if (policy is Map) {
          final name = PolicyReportRow.policyProductName([
            policy['policyName'],
            policy['planName'],
            policy['productName'],
          ]);
          if (name != null) return name;
        }
      } catch (_) {
        // An unavailable snapshot can still have a corresponding saved policy.
      }
    }
    if (row.policyId.isEmpty) return null;
    try {
      return await widget.loadPolicyProductName(row.policyId);
    } catch (_) {
      return null;
    }
  }

  Widget _withName(PolicyReportRow row, int index, Widget Function(String) build) {
    final name = row.productName;
    if (name != null && name.toLowerCase() != row.insuranceCompany.trim().toLowerCase()) return build(name);
    final reportId = _reportId(row);
    final fallback = row.displayName == 'Policy' && widget.group.policyReports.length > 1
        ? 'Policy ${index + 1}'
        : row.displayName;
    return FutureBuilder<String?>(
      future: _names.putIfAbsent((row.policyId, reportId), () => _resolveName(row, reportId)),
      builder: (_, snapshot) => build(snapshot.data ?? fallback),
    );
  }

  int _rank(PolicyReportRow row) => switch (_status(row).$1) {
    CheckStatusKind.covered => 0,
    CheckStatusKind.partial => 1,
    CheckStatusKind.notCovered => 2,
    _ => 3,
  };

  void _select(int index, PolicyReportRow row, double cardWidth) {
    setState(() {
      _policyKey = row.policyId;
      _expanded = 0;
    });
    if (_tabs.hasClients) {
      final target = (index * (cardWidth + 10) - 28).clamp(0.0, _tabs.position.maxScrollExtent).toDouble();
      if (DsMotion.reduced(context)) {
        _tabs.jumpTo(target);
        return;
      }
      _tabs.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final rows = [...group.policyReports];
    final originalOrder = {for (final (index, row) in rows.indexed) row: index};
    rows.sort((a, b) {
      final order = _rank(a).compareTo(_rank(b));
      return order == 0 ? originalOrder[a]!.compareTo(originalOrder[b]!) : order;
    });
    final selected = rows.where((row) => row.policyId == _policyKey).firstOrNull ?? rows.first;
    final id = _reportId(selected);
    final future = id.isEmpty ? null : _report(id);
    return FutureBuilder<Map<String, dynamic>?>(
      future: future,
      builder: (context, snapshot) {
        final c = context.colors;
        final report = snapshot.connectionState == ConnectionState.done ? snapshot.data : null;
        final prescription = report?['prescriptionJson'];
        final extracted = prescription is Map ? prescription : group.prescription;
        final title = CheckSummary.cleanTreatment(_text(extracted['diagnosis']) ?? group.diagnosis);
        final documentTitle = _text(extracted['title']) ?? 'Treatment document';
        final hasTreatment = group.prescriptionId.isNotEmpty || _text(extracted['diagnosis']) != null;
        final documentMeta = [
          _text(extracted['doctorName']) ?? _text(extracted['doctor']),
          _text(extracted['hospitalName']) ?? _text(extracted['hospital']),
        ].nonNulls.join(' · ');
        final policy = report?['policyJson'];
        final terms = policy is Map ? policy : const {};
        final cover = terms['coverageAmount'] ?? terms['sumInsured'];
        final policyMeta = [
          if (selected.insuranceCompany.trim().isNotEmpty) selected.insuranceCompany.trim(),
          if (cover is num && cover.isFinite && cover > 0)
            NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(cover),
        ].join(' · ');
        final patient = CheckSummary.cleanPatientName(_text(extracted['patientName']) ?? group.patientName);
        final visit = _text(extracted['visitDate']) ?? group.visitDate;
        final date = DateTime.tryParse(visit);
        final meta = [
          if (patient.isNotEmpty) patient,
          if (group.createdAt case final checkedAt?)
            formatActivityTimestamp(checkedAt)
          else if (date != null)
            formatActivityDate(date),
        ];
        final (kind, label) = _status(selected, _text(report?['overallStatus']));
        final items = _maps(report?['comparison']);
        final continuity = report?['policyContinuity'];
        final evidence = report == null
            ? null
            : _evidence.putIfAbsent(id, () => PolicyEvidence(_text(report['policyText'])));
        return PushedShell(
          title: title,
          subtitle: meta.join(' · '),
          titleMaxLines: 2,
          titleStyle: AppTextStyles.title.copyWith(fontSize: 28, height: 34 / 28, color: c.textPrimary),
          onBack: widget.onBack,
          body: ListView(
            padding: const EdgeInsets.only(bottom: DsSpace.sectionGap),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.screenPadding),
                child: Text(
                  '${rows.length} ${rows.length == 1 ? 'policy' : 'policies'} checked',
                  style: AppTextStyles.subheadStrong.copyWith(color: c.textPrimary),
                ),
              ),
              const SizedBox(height: DsSpace.s12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.max(
                    0.0,
                    math.min(252.0, constraints.maxWidth - 2 * DsSpace.screenPadding),
                  );
                  final tabs = [
                    for (final (index, row) in rows.indexed)
                      _withName(
                        row,
                        originalOrder[row]!,
                        (name) => _PolicyTab(
                          name: name,
                          status: _status(row),
                          best: index == 0,
                          selected: identical(row, selected),
                          onTap: () => _select(index, row, width),
                        ),
                      ),
                  ];
                  if (tabs.length == 1) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.screenPadding),
                      child: tabs.single,
                    );
                  }
                  return SingleChildScrollView(
                    controller: _tabs,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.screenPadding),
                    child: Row(
                      spacing: 10,
                      children: [for (final tab in tabs) SizedBox(width: width, child: tab)],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpace.screenPadding,
                  DsSpace.s16,
                  DsSpace.screenPadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s16,
                  children: [
                    _withName(
                      selected,
                      originalOrder[selected]!,
                      (name) => _ResultCard(name: name, kind: kind, label: label),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const AppSkeleton(kind: AppSkeletonKind.card),
                    if (snapshot.hasError ||
                        id.isNotEmpty && snapshot.connectionState == ConnectionState.done && report == null)
                      AppInlineBanner(
                        kind: AppInlineBannerKind.error,
                        message: "Couldn't load this policy's report.",
                        onRetry: () => setState(() {
                          _reports.remove(id);
                          _names.remove((selected.policyId, id));
                        }),
                      ),
                    if (items.isNotEmpty) ...[
                      Text(
                        'What was checked',
                        style: AppTextStyles.subheadStrong.copyWith(color: c.textPrimary),
                      ),
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          color: c.surfaceCard,
                          shape: DsShape.shape(DsShape.radiusXl, side: BorderSide(color: c.borderSubtle)),
                        ),
                        child: Column(
                          children: [
                            for (final (index, item) in items.indexed) ...[
                              if (index > 0) Divider(height: 1, color: c.borderSubtle),
                              _ComparisonRow(
                                item: item,
                                evidence: evidence!,
                                expanded: _expanded == index,
                                onToggle: () => setState(() => _expanded = _expanded == index ? null : index),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (continuity is Map && _text(continuity['status']) != null)
                      PolicyContinuityCard(
                        continuity: Map<String, dynamic>.from(continuity),
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                    if (hasTreatment && widget.onOpenTreatment != null || widget.onOpenPolicy != null) ...[
                      const AppSectionHeader(title: 'Documents'),
                      AppRowGroup(
                        rows: [
                          if (widget.onOpenTreatment case final open? when hasTreatment)
                            AppDocumentRow(
                              type: DocumentCardType.prescription,
                              category: 'Prescription',
                              title: documentTitle,
                              meta: documentMeta,
                              grouped: true,
                              onTap: () => open(
                                documentTitle,
                                [
                                  'Prescription',
                                  if (date != null) DateFormat('d MMM yyyy').format(date.toLocal()),
                                ].join(' · '),
                              ),
                            ),
                          if (widget.onOpenPolicy case final open?)
                            _withName(
                              selected,
                              originalOrder[selected]!,
                              (name) => AppDocumentRow(
                                type: DocumentCardType.policy,
                                category: 'Policy',
                                title: name,
                                meta: policyMeta,
                                grouped: true,
                                onTap: () => open(selected, name, policyMeta),
                              ),
                            ),
                        ],
                      ),
                    ],
                    Text(
                      'An estimate from your documents. Your insurer makes the final decision.',
                      style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PolicyTab extends StatelessWidget {
  const _PolicyTab({
    required this.name,
    required this.status,
    required this.best,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final (CheckStatusKind, String) status;
  final bool best;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      child: AppPressableSurface(
        color: c.surfaceCard,
        radius: 18,
        border: BorderSide(color: selected ? c.buttonPrimary : c.borderSubtle, width: selected ? 2 : 1),
        onTap: onTap,
        semanticLabel: [name, status.$2, if (best) 'Best'].join(', '),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subheadStrong.copyWith(color: c.textPrimary),
                ),
                Row(
                  spacing: DsSpace.s4,
                  children: [
                    Expanded(
                      child: AppStatusLabel(kind: status.$1, label: status.$2),
                    ),
                    if (best) _Tag('Best', positive: status.$1 == CheckStatusKind.covered),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.name, required this.kind, required this.label});

  final String name;
  final CheckStatusKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fill, reason) = switch (kind) {
      CheckStatusKind.covered => (c.statusCoveredBackground, '$name covers this treatment.'),
      CheckStatusKind.partial => (c.statusPartialBackground, '$name covers part of this treatment.'),
      CheckStatusKind.notCovered => (c.statusNotCoveredBackground, "$name doesn't cover this treatment."),
      _ => (c.surfaceCardSubtle, null),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(color: fill, shape: DsShape.shape(22)),
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DsSpace.s8,
          children: [
            Row(
              children: [
                Transform.scale(scale: 1.2, child: AppStatusDot(kind: kind)),
                const SizedBox(width: DsSpace.s8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.title.copyWith(fontSize: 24, height: 30 / 24, color: c.textPrimary),
                  ),
                ),
              ],
            ),
            if (reason != null)
              Text(reason, style: AppTextStyles.subheadRegular.copyWith(color: c.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.item,
    required this.evidence,
    required this.expanded,
    required this.onToggle,
  });

  final Map<String, dynamic> item;
  final PolicyEvidence evidence;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = _text(item['displayName']) ?? _text(item['item']) ?? 'Treatment item';
    final type = _text(item['itemType']);
    final raw = _text(item['coverageStatus']) ?? 'Result not available';
    final kind = CheckSummary.statusKindFor(raw);
    final label = switch (kind) {
      CheckStatusKind.covered => 'Covered',
      CheckStatusKind.partial => 'Partly covered',
      CheckStatusKind.notCovered => 'Not covered',
      _ when raw.toLowerCase().replaceAll('_', ' ') == 'needs verification' => 'Needs info',
      _ => raw,
    };
    final clauses = expanded ? evidence.clausesFor(item) : const <Map<String, dynamic>>[];
    final reason = _text(item['coverageStatusReason']) ?? _text(item['explanation']) ?? _text(item['reason']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPressable(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s4,
                    children: [
                      if (type != null)
                        Text(type, style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary)),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.rowTitle.copyWith(color: c.textPrimary),
                      ),
                      Row(
                        children: [
                          AppStatusDot(kind: kind),
                          const SizedBox(width: DsSpace.s8),
                          Flexible(
                            child: Text(label, style: AppTextStyles.label.copyWith(color: c.textSecondary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                RotatedBox(
                  quarterTurns: expanded ? 2 : 0,
                  child: Icon(AppIcons.caretDown, color: c.iconDefault),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reason != null)
                  Text(
                    reason,
                    style: AppTextStyles.subheadRegular.copyWith(height: 22 / 15, color: c.textPrimary),
                  ),
                AppLink(
                  label: clauses.isEmpty ? 'See policy clauses' : 'See policy clauses (${clauses.length})',
                  trailing: AppIcons.caretRight,
                  onPressed: () =>
                      _openClauses(context, name, clauses, _text(item['policyEvidence']) ?? reason),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PolicyEvidenceCard extends StatelessWidget {
  const _PolicyEvidenceCard({required this.clauses, required this.analysisBasis});

  final List<Map<String, dynamic>> clauses;
  final String? analysisBasis;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpace.s12),
      decoration: ShapeDecoration(
        color: c.surfaceCardSubtle,
        shape: DsShape.shape(DsShape.radiusMd, side: BorderSide(color: c.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          Text('Policy evidence', style: AppTextStyles.subheadStrong.copyWith(color: c.textPrimary)),
          if (clauses.isEmpty) ...[
            Text(
              'Exact policy wording is unavailable for this term.',
              style: AppTextStyles.label.copyWith(color: c.textSecondary),
            ),
            if (analysisBasis case final basis?) ...[
              Text('Analysis basis', style: AppTextStyles.subheadStrong.copyWith(color: c.textPrimary)),
              SelectableText(basis, style: AppTextStyles.secondary.copyWith(color: c.textSecondary)),
            ],
          ],
          for (final clause in clauses)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s8,
              children: [
                if (clauses.length > 1)
                  Text('•', style: AppTextStyles.label.copyWith(color: c.textSecondary)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s4,
                    children: [
                      if (_text(clause['section']) case final section?)
                        Text(section, style: AppTextStyles.subheadStrong.copyWith(color: c.textPrimary)),
                      SelectableText(
                        clause['quote'] as String,
                        style: AppTextStyles.secondary.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

void _openClauses(
  BuildContext context,
  String item,
  List<Map<String, dynamic>> clauses,
  String? analysisBasis,
) {
  final reviewed = clauses.where(
    (clause) =>
        clause['decisive'] is bool || _text(clause['effect']) != null || _text(clause['explanation']) != null,
  );
  final deciding = reviewed.where((clause) => clause['decisive'] == true).toList();
  final considered = clauses.where((clause) => clause['decisive'] != true).toList();
  AppSheet.show<void>(
    context: context,
    title: 'Policy clauses',
    showClose: true,
    bodyBuilder: (context) => AppSheetList(
      rows: [
        Text(item, style: AppTextStyles.subheadRegular.copyWith(color: context.colors.textSecondary)),
        if (reviewed.isNotEmpty)
          for (final (heading, rows) in [
            ('Deciding clauses', deciding),
            ('Also considered', considered),
          ]) ...[
            AppSectionHeader(title: '$heading · ${rows.length}'),
            for (final row in rows) _ClauseCard(row),
          ]
        else
          _PolicyEvidenceCard(clauses: clauses, analysisBasis: analysisBasis),
      ],
    ),
  );
}

class _ClauseCard extends StatelessWidget {
  const _ClauseCard(this.clause);

  final Map<String, dynamic> clause;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: c.surfaceCardSubtle,
        shape: DsShape.shape(18, side: BorderSide(color: c.borderDivider)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            if (_text(clause['effect']) case final effect?)
              Align(alignment: AlignmentDirectional.centerStart, child: _Tag(effect)),
            Text(
              _text(clause['section']) ?? 'Policy clause',
              style: AppTextStyles.rowTitle.copyWith(color: c.textPrimary),
            ),
            if (_text(clause['quote']) case final text?)
              SelectableText(
                '\u201c$text\u201d',
                style: AppTextStyles.reportBody.copyWith(color: c.textPrimary),
              ),
            if (_text(clause['explanation']) case final explanation?)
              Text(explanation, style: AppTextStyles.secondary.copyWith(color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.positive = false});
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: positive ? context.colors.statusCoveredBackground : null,
      shape: DsShape.shape(DsShape.radiusFull, side: BorderSide(color: context.colors.borderDivider)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s2),
      child: Text(
        label,
        style: AppTextStyles.chip.copyWith(
          color: positive ? context.colors.statusCovered : context.colors.textSecondary,
        ),
      ),
    ),
  );
}

String? _text(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

List<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? [for (final item in value.whereType<Map<String, dynamic>>()) item] : const [];
