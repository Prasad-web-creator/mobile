import 'package:flutter/material.dart';

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
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/documents/presentation/document_summary.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_card.dart';
import 'package:claimsupport/features/home/presentation/widgets/check_stack.dart';

class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  Brightness? _brightness;
  AppCheckFilter _filter = AppCheckFilter.all;
  final _selectedPolicy = <int, int>{};

  @override
  Widget build(BuildContext context) {
    final brightness = _brightness ?? Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return Theme(
      data: ThemeData(
        brightness: brightness,
        extensions: [
          dark ? AppColors.dark : AppColors.light,
          dark ? AppIllustrationColors.dark : AppIllustrationColors.light,
        ],
      ),
      child: RootShell(
        title: 'Component gallery',
        navigation: const SizedBox.shrink(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.screenPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Semantics(
                    selected: !dark,
                    child: AppLink(label: 'Light', onPressed: () => setState(() => _brightness = Brightness.light)),
                  ),
                  Semantics(
                    selected: dark,
                    child: AppLink(label: 'Dark', onPressed: () => setState(() => _brightness = Brightness.dark)),
                  ),
                ],
              ),
            ),
            Expanded(child: Builder(builder: (context) => _specimens(context))),
          ],
        ),
      ),
    );
  }

  Widget _specimens(BuildContext context) => ListView(
    key: const PageStorageKey('component specimens'),
    padding: const EdgeInsets.fromLTRB(DsSpace.screenPadding, DsSpace.s8, DsSpace.screenPadding, DsSpace.s32),
    children: [
      _Group('Buttons, glass controls and links', [
        AppButton(label: 'Check coverage', onPressed: _ignore),
        AppButton(label: 'Start your first check', style: AppButtonStyle.secondary, onPressed: _ignore),
        const AppButton(label: 'Disabled', onPressed: null),
        const AppButton(label: 'Reading your documents…', onPressed: null, busy: true),
        AppButton(label: 'Primary pressed', onPressed: _ignore, showPressed: true),
        AppButton(label: 'Secondary pressed', style: AppButtonStyle.secondary, onPressed: _ignore, showPressed: true),
        Wrap(
          spacing: DsSpace.s8,
          children: [
            AppIconButton(icon: AppIcons.caretLeft, label: 'Back', onPressed: _ignore),
            AppIconButton(icon: AppIcons.close, label: 'Close', onPressed: _ignore),
            AppIconButton(icon: AppIcons.share, label: 'Share', onPressed: _ignore),
            AppIconButton(icon: AppIcons.share, label: 'Share pressed', onPressed: _ignore, showPressed: true),
          ],
        ),
        Wrap(
          children: [
            AppLink(label: 'See all', trailing: AppIcons.caretRight, onPressed: _ignore),
            AppLink(label: 'Link pressed', onPressed: _ignore, showPressed: true),
          ],
        ),
      ]),
      _Group('Check cards', [
        for (final check in _checks) AppCheckCard(check: check, onTap: () => _openCheck(context, check)),
      ]),
      _Group('Check stacks', [
        for (final count in [1, 2, 3]) ...[
          AppSectionHeader(title: '$count ${count == 1 ? 'card' : 'cards'}'),
          AppCheckStack(
            checks: _checks.take(count).toList(),
            onOpen: (check) => _openCheck(context, check),
            onSeeAll: count == 3 ? () => _openSheet(context, 'Recent checks', _checkRows) : null,
          ),
        ],
      ]),
      _Group('Check rows', [
        for (final check in _checks) AppCheckRow(check: check, onTap: () => _openCheck(context, check)),
      ]),
      _Group('Document cards', [
        for (final count in <int?>[0, 24, 123, null])
          Row(
            spacing: DsSpace.gridGap,
            children: [
              for (final type in DocumentCardType.values)
                Expanded(
                  child: AppDocumentCard(type: type, count: count, onTap: _ignore),
                ),
            ],
          ),
      ]),
      _Group('Document rows', [
        ..._documentRows(context),
        AppDocumentRow(
          type: DocumentCardType.prescription,
          title: 'DS summary',
          state: AppDocumentState.failed,
          onTap: _ignore,
        ),
        AppDocumentRow(type: DocumentCardType.policy, title: '', state: AppDocumentState.unknown, onTap: _ignore),
      ]),
      _Group('Status dots and pills', [
        for (final check in _checks)
          Row(
            children: [
              AppStatusDot(kind: check.statusKind),
              const SizedBox(width: DsSpace.s8),
              Flexible(
                child: AppStatusPill(kind: check.statusKind, label: check.statusLabel),
              ),
            ],
          ),
      ]),
      _Group('Section headers', [
        const AppSectionHeader(title: 'Documents'),
        AppSectionHeader(title: 'Documents', onSeeAll: () => _openSheet(context, 'Documents', _documentRowsSheet)),
      ]),
      _Group('Filter chips', [
        AppFilterChips(selected: _filter, onChanged: (filter) => setState(() => _filter = filter)),
      ]),
      _Group('Policy switchers', [
        for (final count in [2, 3, 4, 5]) ...[
          AppSectionHeader(title: '$count policies'),
          AppPolicySwitcher(
            policies: _policies.take(count).toList(),
            selectedIndex: _selectedPolicy[count] ?? 0,
            onChanged: (index) => setState(() => _selectedPolicy[count] = index),
          ),
        ],
      ]),
      _Group('Empty state', [
        AppEmptyState(
          illustration: AppIllustrationKind.prescription,
          message: 'No checks yet',
          actionLabel: 'Start a check',
          onAction: _ignore,
        ),
      ]),
      const _Group('Skeletons', [
        AppSkeleton(kind: AppSkeletonKind.card),
        AppSkeleton(kind: AppSkeletonKind.row),
        Row(
          children: [
            Expanded(child: AppSkeleton(kind: AppSkeletonKind.documentCard)),
            SizedBox(width: DsSpace.gridGap),
            Expanded(child: AppSkeleton(kind: AppSkeletonKind.documentCard)),
          ],
        ),
      ]),
      _Group('Inline banners', [
        const AppInlineBanner(kind: AppInlineBannerKind.info, message: 'Reading your documents…'),
        const AppInlineBanner(kind: AppInlineBannerKind.offline, message: "You're offline. Showing saved checks."),
        AppInlineBanner(
          kind: AppInlineBannerKind.error,
          message: "Couldn't read this document. Try a clearer photo.",
          onRetry: _ignore,
        ),
      ]),
      const _Group('Step indicators', [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [AppStepIndicator(step: 1), AppStepIndicator(step: 2)],
        ),
      ]),
      _Group('Sheet content', [
        AppButton(label: 'Open list sheet', onPressed: () => _openSheet(context, 'Documents', _documentRowsSheet)),
        AppButton(label: 'Open key/value sheet', onPressed: () => _openSheet(context, 'Policy', _policyDetails)),
        AppButton(
          label: 'Open confirmation sheet',
          onPressed: () => _openSheet(context, 'Remove this policy?', _confirmation),
        ),
      ]),
    ],
  );

  void _openCheck(BuildContext context, CheckSummary check) =>
      _openSheet(context, check.treatment, (_) => AppStatusPill(kind: check.statusKind, label: check.statusLabel));

  void _openSheet(BuildContext context, String title, WidgetBuilder bodyBuilder) =>
      AppSheet.show<void>(context: context, title: title, bodyBuilder: bodyBuilder);

  Widget _checkRows(BuildContext context) => AppSheetList(
    rows: [for (final check in _checks) AppCheckRow(check: check, onTap: () => Navigator.pop(context))],
  );

  List<Widget> _documentRows(BuildContext context) => [
    for (final document in _documents)
      AppDocumentRow(
        type: document.type,
        title: document.title,
        meta: document.meta,
        state: document.state,
        onTap: () => _openSheet(
          context,
          document.title,
          (_) => AppSheetKeyValue(label: 'Details', value: document.state.label ?? document.meta),
        ),
      ),
  ];

  Widget _documentRowsSheet(BuildContext context) => AppSheetList(rows: _documentRows(context));

  Widget _policyDetails(BuildContext context) => const AppSheetList(
    rows: [
      AppSheetKeyValue(label: 'Insurer', value: 'Star Health'),
      AppSheetKeyValue(label: 'Policy', value: 'Prakriti Family Health Secure'),
      AppSheetKeyValue(label: 'Renewal date', value: '12 Oct'),
    ],
  );

  Widget _confirmation(BuildContext context) => AppSheetConfirmation(
    message: 'Remove this policy from this check?',
    actionLabel: 'Remove policy',
    onConfirm: () => Navigator.pop(context),
    onCancel: () => Navigator.pop(context),
  );

  static void _ignore() {}
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: DsSpace.sectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        AppSectionHeader(title: title),
        ...children,
      ],
    ),
  );
}

const _checks = [
  CheckSummary(
    id: 'covered',
    treatment: 'Appendicitis',
    patientName: 'Rajesh',
    dateLabel: 'Today',
    meta: 'For Rajesh · Best with Prakriti',
    statusLabel: 'Fully covered',
    statusKind: CheckStatusKind.covered,
    route: '',
  ),
  CheckSummary(
    id: 'partial',
    treatment: 'Treatment plan for a complicated lower-limb fracture with follow-up physiotherapy and imaging',
    patientName: 'Isha',
    dateLabel: 'Yesterday',
    meta: 'For Isha · Best with Navyug',
    statusLabel: 'Partially covered',
    statusKind: CheckStatusKind.partial,
    route: '',
  ),
  CheckSummary(
    id: 'not-covered',
    treatment: 'Routine consultation',
    dateLabel: '12 Oct',
    meta: 'Star Health',
    statusLabel: 'Not covered',
    statusKind: CheckStatusKind.notCovered,
    route: '',
  ),
  CheckSummary(
    id: 'checking',
    treatment: 'Prescription',
    dateLabel: 'Today',
    meta: '',
    statusLabel: 'Checking…',
    statusKind: CheckStatusKind.checking,
    route: '',
  ),
  CheckSummary(
    id: 'failed',
    treatment: 'Prescription',
    dateLabel: '12 Oct 2025',
    meta: '',
    statusLabel: "Couldn't read",
    statusKind: CheckStatusKind.failed,
    route: '',
  ),
  CheckSummary(
    id: 'unknown',
    treatment: 'Review consultation',
    dateLabel: '',
    meta: '',
    statusLabel: 'Manual review required',
    statusKind: CheckStatusKind.other,
    route: '',
  ),
];

const _policies = [
  AppPolicyOption(
    label: 'Prakriti Family Health Secure',
    kind: CheckStatusKind.covered,
    statusLabel: 'Fully covered',
    best: true,
  ),
  AppPolicyOption(label: 'Navyug', kind: CheckStatusKind.partial, statusLabel: 'Partially covered'),
  AppPolicyOption(label: 'Star Health', kind: CheckStatusKind.notCovered, statusLabel: 'Not covered'),
  AppPolicyOption(label: 'Family Health', kind: CheckStatusKind.checking, statusLabel: 'Checking…'),
  AppPolicyOption(label: 'Hospital Care', kind: CheckStatusKind.other, statusLabel: 'Status unavailable'),
];

final _reviewDate = DateTime(2026, 11, 26);
final _documents = [
  DocumentSummary.prescription(
    Prescription.fromJson({
      'originalFileName': 'Follow-up prescription',
      'patientName': 'Rajesh',
      'visitDate': '2026-11-25',
    }),
    now: _reviewDate,
  ),
  DocumentSummary.policy(
    Policy.fromJson({
      'policyName': 'Prakriti Family Health Secure',
      'insuranceCompany': 'Star Health',
      'policyEndDate': '2026-12-12',
    }),
    now: _reviewDate,
  ),
  DocumentSummary.policy(Policy.fromJson({'policyName': 'Navyug', 'policyEndDate': '2026-10-12'}), now: _reviewDate),
  DocumentSummary.prescription(Prescription.fromJson({'processingStatus': 'pending'}), now: _reviewDate),
];
