import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';

/// Coverage Analysis Reports screen.
///
/// Groups policies analyzed against the same prescription under one clean,
/// expandable parent report card.
class AnalysesReportsScreen extends ConsumerStatefulWidget {
  const AnalysesReportsScreen({super.key});

  @override
  ConsumerState<AnalysesReportsScreen> createState() => _AnalysesReportsScreenState();
}

class _AnalysesReportsScreenState extends ConsumerState<AnalysesReportsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedGroupIds = {};
  final Set<String> _expandedGroupIds = {};

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _isSelectionMode = true;
      if (initialId != null) {
        _selectedGroupIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedGroupIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedGroupIds.contains(id)) {
        _selectedGroupIds.remove(id);
        if (_selectedGroupIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedGroupIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<AnalysisReportGroup> currentGroups) {
    setState(() {
      final allIds = currentGroups.map((g) => g.groupId).toSet();
      if (_selectedGroupIds.containsAll(allIds)) {
        _selectedGroupIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedGroupIds.addAll(allIds);
      }
    });
  }

  void _toggleExpand(String groupId) {
    setState(() {
      if (_expandedGroupIds.contains(groupId)) {
        _expandedGroupIds.remove(groupId);
      } else {
        _expandedGroupIds.add(groupId);
      }
    });
  }

  Future<void> _confirmBatchDelete() async {
    if (_selectedGroupIds.isEmpty) return;
    final count = _selectedGroupIds.length;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Selected Analyses',
      message:
          'Are you sure you want to permanently delete $count selected analysis/analyses? '
          'All policy reports inside them will be removed. This action cannot be undone.',
      confirmLabel: 'Delete All',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed == true) {
      try {
        final idsToDelete = _selectedGroupIds.toList();
        await ref.read(analysisReportProvider.notifier).deleteReports(idsToDelete);
        if (mounted) {
          showAppSnackBar(context, '$count analyses deleted successfully.', tone: AppTone.success);
          _exitSelectionMode();
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Failed to delete analyses: ${friendlyErrorMessage(e)}', tone: AppTone.danger);
        }
      }
    }
  }

  Future<void> _confirmDeleteSingle(AnalysisReportGroup group) async {
    final label = group.title;
    final extra = group.isMultiPolicy
        ? ' All ${group.policyCount} policy reports in this analysis will be removed.'
        : '';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Analysis',
      message: 'Are you sure you want to delete "$label"?$extra This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      try {
        await ref.read(analysisReportProvider.notifier).deleteReport(group.groupId);
        if (mounted) {
          showAppSnackBar(context, 'Analysis deleted successfully.', tone: AppTone.success);
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Failed to delete: ${friendlyErrorMessage(e)}', tone: AppTone.danger);
        }
      }
    }
  }

  /// Tone + icon for a report / job status label. Job states (failed, analyzing,
  /// needs your input, completed) are handled here; coverage outcomes use the
  /// shared [coverageStatusStyle] so they match the rest of the app.
  CoverageStatusStyle _statusStyle(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('fail')) return const CoverageStatusStyle(AppTone.danger, Icons.cancel_outlined);
    if (lower.contains('invalid')) return const CoverageStatusStyle(AppTone.danger, Icons.error_outline_rounded);
    if (lower.contains('analyzing') || lower.contains('queued') || lower.contains('extracting')) {
      return const CoverageStatusStyle(AppTone.neutral, Icons.hourglass_empty_rounded);
    }
    if (lower.contains('needs your input')) {
      return const CoverageStatusStyle(AppTone.warning, Icons.edit_note_rounded);
    }
    if (lower == 'completed') {
      return const CoverageStatusStyle(AppTone.success, Icons.check_circle_outline_rounded);
    }
    return coverageStatusStyle(label, fallback: AppTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(analysisReportProvider);
    final p = context.palette;

    // Every group starts collapsed: a card opens only when the user taps it.
    final currentGroups = reportState.value?.docs ?? [];

    final validIds = currentGroups.map((g) => g.groupId).toSet();
    final allSelected = validIds.isNotEmpty && _selectedGroupIds.containsAll(validIds);

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              toolbarHeight: 72,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
                tooltip: 'Cancel Selection',
              ),
              title: Text('${_selectedGroupIds.length} Selected'),
              actions: [
                TextButton(
                  onPressed: () => _toggleSelectAll(currentGroups),
                  child: Text(allSelected ? 'Deselect All' : 'Select All'),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: _selectedGroupIds.isNotEmpty ? p.danger.fg : p.danger.fg.withAlpha(110),
                    ),
                    tooltip: 'Delete Selected',
                    onPressed: _selectedGroupIds.isNotEmpty ? _confirmBatchDelete : null,
                  ),
                ),
              ],
            )
          : TabAppBar(
              title: 'Reports',
              subtitle: 'Tap a report to see each policy\'s coverage result',
              actions: [
                if (currentGroups.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.checklist_rounded),
                    tooltip: 'Select / Manage',
                    onPressed: () => _enterSelectionMode(),
                  ),
              ],
            ),
      body: SafeArea(
        child: reportState.when(
          data: (pagination) {
            final groups = pagination.docs;
            if (groups.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(analysisReportProvider.notifier).fetchAnalysisReports(isRefresh: true);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    EmptyState(
                      icon: Icons.description_outlined,
                      title: 'No reports yet',
                      message:
                          'Start a new analysis from the Home tab. Your coverage reports will be saved here for later.',
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(analysisReportProvider.notifier).fetchAnalysisReports(isRefresh: true);
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
                itemCount: groups.length + (pagination.hasNextPage ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == groups.length) {
                    Future.microtask(() => ref.read(analysisReportProvider.notifier).loadNextPage());
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)),
                      ),
                    );
                  }
                  return ContentWidth(child: _buildGroupCard(groups[index]));
                },
              ),
            );
          },
          loading: () => const LoadingState(message: 'Loading your reports…'),
          error: (err, stack) => ErrorState(
            title: 'Couldn\'t load reports',
            message: friendlyErrorMessage(err),
            onRetry: () => ref.invalidate(analysisReportProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(AnalysisReportGroup group) {
    final p = context.palette;
    final isSelected = _selectedGroupIds.contains(group.groupId);
    final isExpanded = _expandedGroupIds.contains(group.groupId);
    final statusLabel = group.statusLabel;
    final style = _statusStyle(statusLabel);

    final dateStr = group.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(group.createdAt!.toLocal())
        : '';

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      color: isSelected ? p.primarySoft : null,
      borderColor: isSelected ? p.primary : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onLongPress: () => _enterSelectionMode(group.groupId),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(group.groupId);
            } else {
              _toggleExpand(group.groupId);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: icon / checkbox, title + status, overflow menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSelectionMode)
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(group.groupId)),
                      )
                    else
                      const IconTile(icon: Icons.assignment_outlined, tone: AppTone.brand),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          StatusBadge(label: statusLabel, tone: style.tone, icon: style.icon, dense: true),
                        ],
                      ),
                    ),
                    if (!_isSelectionMode)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: PopupMenuButton<String>(
                          tooltip: 'More actions',
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: Icon(Icons.more_vert_rounded, color: p.textTertiary),
                          onSelected: (value) {
                            if (value == 'delete') _confirmDeleteSingle(group);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 20, color: p.danger.fg),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text('Delete', style: TextStyle(color: p.danger.fg)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Details
                const SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: p.border),
                const SizedBox(height: AppSpacing.xs),
                if (group.patientName.isNotEmpty)
                  _buildMetaRow(Icons.person_outline_rounded, 'Patient', group.patientName),
                if (group.displayVisitDate.isNotEmpty)
                  _buildMetaRow(Icons.calendar_today_outlined, 'Prescription date', group.displayVisitDate)
                else if (group.visitDate.isNotEmpty)
                  _buildMetaRow(Icons.calendar_today_outlined, 'Prescription date', group.visitDate),
                _buildMetaRow(Icons.policy_outlined, 'Policies checked', '${group.policyCount}'),
                if (dateStr.isNotEmpty) _buildMetaRow(Icons.schedule_rounded, 'Checked on', dateStr),
                if (group.displayProcessingTime.isNotEmpty)
                  _buildMetaRow(Icons.timer_outlined, 'Processing time', group.displayProcessingTime),

                // Expand / collapse toggle for the per-policy results
                if (group.policyReports.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Divider(height: 1, color: p.border),
                  InkWell(
                    borderRadius: AppRadius.smAll,
                    onTap: () => _toggleExpand(group.groupId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isExpanded
                                  ? 'Hide policy results'
                                  : 'View policy results (${group.policyReports.length})',
                              style: context.text.labelLarge?.copyWith(color: p.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: p.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(height: AppSpacing.xs),

                // Nested policies (visible when expanded)
                if (isExpanded && group.policyReports.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: group.policyReports.map(_buildNestedPolicyCard).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One policy's result inside an expanded analysis group.
  Widget _buildNestedPolicyCard(PolicyReportRow policy) {
    final p = context.palette;
    final style = _statusStyle(policy.statusLabel);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: p.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: () {
            if (policy.hasReport) {
              context.push('/summary/${policy.reportId}');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconTile(icon: Icons.shield_outlined, tone: AppTone.brand, size: 34),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        policy.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        policy.policyNumber.isNotEmpty
                            ? 'Policy No: ${policy.policyNumber}'
                            : (policy.insuranceCompany.isNotEmpty ? policy.insuranceCompany : 'Policy No: ---'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                      if (policy.displayPeriod.isNotEmpty)
                        Text(
                          'Period: ${policy.displayPeriod}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall,
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      StatusBadge(label: policy.statusLabel, tone: style.tone, icon: style.icon, dense: true),
                      if (policy.isFailed && policy.errorMessage.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(policy.errorMessage, style: context.text.bodySmall?.copyWith(color: p.danger.fg)),
                      ],
                    ],
                  ),
                ),
                if (policy.hasReport)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xxs, top: 6),
                    child: Icon(Icons.chevron_right_rounded, size: 22, color: p.textTertiary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Icon + label + value metadata row. Labels sit in a fixed-width column so
  /// every value in the card lines up.
  Widget _buildMetaRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty || value.trim() == '---' || value.trim() == 'N/A') {
      return const SizedBox.shrink();
    }
    final p = context.palette;
    final base = context.text.bodyMedium?.copyWith(fontSize: 13, height: 1.4);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: p.textTertiary),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 116,
            child: Text(label, style: base?.copyWith(color: p.textTertiary)),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(value, style: base?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
