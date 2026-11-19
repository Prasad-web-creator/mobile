import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:intl/intl.dart';

class PolicyListScreen extends ConsumerStatefulWidget {
  const PolicyListScreen({super.key});

  @override
  ConsumerState<PolicyListScreen> createState() => _PolicyListScreenState();
}

class _PolicyListScreenState extends ConsumerState<PolicyListScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedPolicyIds = {};

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _isSelectionMode = true;
      if (initialId != null) {
        _selectedPolicyIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPolicyIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedPolicyIds.contains(id)) {
        _selectedPolicyIds.remove(id);
        if (_selectedPolicyIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPolicyIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<Policy> currentPolicies) {
    setState(() {
      final allIds = currentPolicies.map((p) => p.id).toSet();
      if (_selectedPolicyIds.containsAll(allIds)) {
        _selectedPolicyIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedPolicyIds.addAll(allIds);
      }
    });
  }

  Future<void> _confirmBatchDelete() async {
    if (_selectedPolicyIds.isEmpty) return;
    final count = _selectedPolicyIds.length;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Selected Policies',
      message:
          'Are you sure you want to permanently delete $count selected policy/policies? This action cannot be undone.',
      confirmLabel: 'Delete All',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed == true) {
      try {
        final idsToDelete = _selectedPolicyIds.toList();
        await ref.read(policiesProvider.notifier).deletePolicies(idsToDelete);
        if (mounted) {
          showAppSnackBar(context, '$count policies deleted successfully.', tone: AppTone.success);
          _exitSelectionMode();
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Failed to delete policies: ${friendlyErrorMessage(e)}', tone: AppTone.danger);
        }
      }
    }
  }

  Future<void> _confirmDeleteSingle(String id, String label) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Policy',
      message: 'Are you sure you want to delete "$label"? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      try {
        await ref.read(policiesProvider.notifier).deletePolicy(id);
        if (mounted) {
          showAppSnackBar(context, 'Policy deleted successfully.', tone: AppTone.success);
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Failed to delete: ${friendlyErrorMessage(e)}', tone: AppTone.danger);
        }
      }
    }
  }

  bool _hasValue(String? v) => v != null && v.trim().isNotEmpty && v != '---' && !v.toLowerCase().startsWith('unknown');

  @override
  Widget build(BuildContext context) {
    final policyState = ref.watch(policiesProvider);
    final p = context.palette;

    final currentPolicies = policyState.value?.docs ?? [];
    final allSelected = currentPolicies.isNotEmpty && _selectedPolicyIds.containsAll(currentPolicies.map((p) => p.id));

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
                tooltip: 'Cancel Selection',
              )
            : null,
        title: Text(_isSelectionMode ? '${_selectedPolicyIds.length} Selected' : 'My Policies'),
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: () => _toggleSelectAll(currentPolicies),
              child: Text(allSelected ? 'Deselect All' : 'Select All'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xxs),
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: _selectedPolicyIds.isNotEmpty ? p.danger.fg : p.danger.fg.withAlpha(110),
                ),
                tooltip: 'Delete Selected',
                onPressed: _selectedPolicyIds.isNotEmpty ? _confirmBatchDelete : null,
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xxs),
              child: IconButton(
                icon: const Icon(Icons.checklist_rounded),
                tooltip: 'Select Multiple',
                onPressed: () => _enterSelectionMode(),
              ),
            ),
          ],
        ],
      ),
      body: policyState.when(
        data: (pagination) {
          final policies = List<Policy>.from(pagination.docs)
            ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          if (policies.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(policiesProvider.notifier).fetchPolicies(isRefresh: true);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyState(
                    icon: Icons.policy_outlined,
                    title: 'No policies yet',
                    message: 'Policies you upload while checking claim eligibility will appear here.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(policiesProvider.notifier).fetchPolicies(isRefresh: true);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
              itemCount: policies.length + (pagination.hasNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == policies.length) {
                  ref.read(policiesProvider.notifier).loadNextPage();
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)),
                    ),
                  );
                }

                final policy = policies[index];
                return ContentWidth(child: _buildPolicyCard(context, policy));
              },
            ),
          );
        },
        loading: () => const LoadingState(message: 'Loading your policies…'),
        error: (err, stack) => ErrorState(
          title: 'Couldn\'t load policies',
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(policiesProvider),
        ),
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context, Policy policy) {
    final p = context.palette;
    final label = policy.displayId;
    final isSelected = _selectedPolicyIds.contains(policy.id);

    final policyDisplayName = policy.policyName.trim().isNotEmpty && policy.policyName != 'Uploaded Policy'
        ? policy.policyName
        : (policy.insuranceCompany.trim().isNotEmpty
              ? (policy.policyType != null && policy.policyType!.isNotEmpty
                    ? "${policy.insuranceCompany} - ${policy.policyType}"
                    : policy.insuranceCompany)
              : (policy.originalFileName ?? 'Insurance Policy'));

    final dateFmt = DateFormat('dd MMM yyyy');
    final formattedStart = policy.policyStartDate != null ? dateFmt.format(policy.policyStartDate!.toLocal()) : null;
    final formattedEnd = policy.policyEndDate != null ? dateFmt.format(policy.policyEndDate!.toLocal()) : null;
    final isActive = policy.status == 'Active';

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      color: isSelected ? p.primarySoft : null,
      borderColor: isSelected ? p.primary : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onLongPress: () => _enterSelectionMode(policy.id),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(policy.id);
            } else {
              if (policy.gridFsFileId != null) {
                context.push('/view-pdf/${policy.gridFsFileId}?title=${policy.displayId}');
              } else {
                showAppSnackBar(context, 'No PDF document attached to this policy.', tone: AppTone.info);
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xxs, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(policy.id)),
                        ),
                      )
                    else ...[
                      const IconTile(icon: Icons.shield_outlined, tone: AppTone.brand),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            policyDisplayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xxs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusBadge(label: policy.displayId, tone: AppTone.brand, dense: true),
                              StatusBadge(
                                label: policy.status,
                                tone: isActive ? AppTone.success : AppTone.danger,
                                icon: isActive ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                                dense: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!_isSelectionMode)
                      PopupMenuButton<String>(
                        tooltip: 'More actions',
                        icon: Icon(Icons.more_vert_rounded, color: p.textTertiary),
                        onSelected: (value) {
                          if (value == 'delete') _confirmDeleteSingle(policy.id, label);
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
                      )
                    else
                      const SizedBox(width: AppSpacing.sm),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Divider(color: p.border),
                      const SizedBox(height: AppSpacing.xs),
                      if (_hasValue(policy.policyHolderName))
                        _MetaLine(icon: Icons.person_outline_rounded, label: 'Holder', value: policy.policyHolderName!),
                      if (_hasValue(policy.policyNumber))
                        _MetaLine(icon: Icons.tag_rounded, label: 'Policy No.', value: policy.policyNumber),
                      if (formattedStart != null && formattedEnd != null)
                        _MetaLine(
                          icon: Icons.calendar_today_outlined,
                          label: 'Validity',
                          value: '$formattedStart – $formattedEnd',
                        )
                      else if (formattedStart != null)
                        _MetaLine(icon: Icons.calendar_today_outlined, label: 'Start Date', value: formattedStart)
                      else if (formattedEnd != null)
                        _MetaLine(icon: Icons.event_busy_outlined, label: 'Expiry', value: formattedEnd),
                      if (policy.originalFileName != null &&
                          policy.originalFileName!.trim().isNotEmpty &&
                          policy.originalFileName != '---')
                        _MetaLine(
                          icon: Icons.insert_drive_file_outlined,
                          label: 'File',
                          value: policy.originalFileName!,
                          singleLine: true,
                        ),
                      if (policy.createdAt != null)
                        _MetaLine(
                          icon: Icons.schedule_rounded,
                          label: 'Uploaded',
                          value: DateFormat('dd MMM yyyy, hh:mm a').format(policy.createdAt!.toLocal()),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + "Label: value" metadata line used inside list cards.
class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool singleLine;

  const _MetaLine({required this.icon, required this.label, required this.value, this.singleLine = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: p.textTertiary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(color: p.textTertiary),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              maxLines: singleLine ? 1 : null,
              overflow: singleLine ? TextOverflow.ellipsis : null,
              style: context.text.bodyMedium?.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
