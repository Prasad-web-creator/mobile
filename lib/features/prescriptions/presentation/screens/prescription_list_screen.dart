import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:intl/intl.dart';

class PrescriptionListScreen extends ConsumerStatefulWidget {
  const PrescriptionListScreen({super.key});

  @override
  ConsumerState<PrescriptionListScreen> createState() => _PrescriptionListScreenState();
}

class _PrescriptionListScreenState extends ConsumerState<PrescriptionListScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedPrescriptionIds = {};

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _isSelectionMode = true;
      if (initialId != null) {
        _selectedPrescriptionIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPrescriptionIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedPrescriptionIds.contains(id)) {
        _selectedPrescriptionIds.remove(id);
        if (_selectedPrescriptionIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPrescriptionIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<Prescription> currentPrescriptions) {
    setState(() {
      final allIds = currentPrescriptions.map((p) => p.id).toSet();
      if (_selectedPrescriptionIds.containsAll(allIds)) {
        _selectedPrescriptionIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedPrescriptionIds.addAll(allIds);
      }
    });
  }

  Future<void> _confirmBatchDelete() async {
    if (_selectedPrescriptionIds.isEmpty) return;
    final count = _selectedPrescriptionIds.length;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Selected Prescriptions',
      message:
          'Are you sure you want to permanently delete $count selected prescription(s)? This action cannot be undone.',
      confirmLabel: 'Delete All',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed == true) {
      try {
        final idsToDelete = _selectedPrescriptionIds.toList();
        await ref.read(prescriptionProvider.notifier).deletePrescriptions(idsToDelete);
        if (mounted) {
          showAppSnackBar(context, '$count prescriptions deleted successfully.', tone: AppTone.success);
          _exitSelectionMode();
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Failed to delete prescriptions: ${friendlyErrorMessage(e)}', tone: AppTone.danger);
        }
      }
    }
  }

  Future<void> _confirmDeleteSingle(String id, String label) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Prescription',
      message: 'Are you sure you want to delete "$label"? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      try {
        await ref.read(prescriptionProvider.notifier).deletePrescription(id);
        if (mounted) {
          showAppSnackBar(context, 'Prescription deleted successfully.', tone: AppTone.success);
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Failed to delete: ${friendlyErrorMessage(e)}', tone: AppTone.danger);
        }
      }
    }
  }

  void _showManualPrescriptionDialog(BuildContext context, Prescription rx) {
    final String medText = (rx.manualText != null && rx.manualText!.trim().isNotEmpty)
        ? rx.manualText!.trim()
        : ((rx.diagnosis != null && rx.diagnosis!.trim().isNotEmpty)
              ? rx.diagnosis!.trim()
              : ((rx.extractedPrescriptionText != null && rx.extractedPrescriptionText!.trim().isNotEmpty)
                    ? rx.extractedPrescriptionText!.trim()
                    : '---'));

    final dateFmt = DateFormat('dd MMM yyyy');
    final String dateStr = rx.visitDate != null
        ? dateFmt.format(rx.visitDate!.toLocal())
        : (rx.createdAt != null ? dateFmt.format(rx.createdAt!.toLocal()) : dateFmt.format(DateTime.now()));

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final p = dialogCtx.palette;
        return AlertDialog(
          title: Row(
            children: [
              const IconTile(icon: Icons.edit_note_rounded, tone: AppTone.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Self-Entered Prescription', style: dialogCtx.text.titleMedium),
                    Text(rx.displayId, style: dialogCtx.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: p.surfaceMuted,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entered Medical Details / Symptoms',
                        style: dialogCtx.text.labelMedium?.copyWith(color: p.success.fg, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(medText, style: dialogCtx.text.bodyLarge),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _MetaLine(icon: Icons.calendar_today_outlined, label: 'Date', value: dateStr),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Close'))],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prescriptionState = ref.watch(prescriptionProvider);
    final p = context.palette;

    final currentPrescriptions = prescriptionState.value?.docs ?? [];
    final allSelected =
        currentPrescriptions.isNotEmpty && _selectedPrescriptionIds.containsAll(currentPrescriptions.map((p) => p.id));

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
                tooltip: 'Cancel Selection',
              )
            : null,
        title: Text(_isSelectionMode ? '${_selectedPrescriptionIds.length} Selected' : 'My Prescriptions'),
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: () => _toggleSelectAll(currentPrescriptions),
              child: Text(allSelected ? 'Deselect All' : 'Select All'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xxs),
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: _selectedPrescriptionIds.isNotEmpty ? p.danger.fg : p.danger.fg.withAlpha(110),
                ),
                tooltip: 'Delete Selected',
                onPressed: _selectedPrescriptionIds.isNotEmpty ? _confirmBatchDelete : null,
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
      body: prescriptionState.when(
        data: (pagination) {
          final prescriptions = List<Prescription>.from(pagination.docs)
            ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          if (prescriptions.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(prescriptionProvider.notifier).fetchPrescriptions(isRefresh: true);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyState(
                    icon: Icons.medication_outlined,
                    title: 'No prescriptions yet',
                    message: 'Prescriptions you upload or enter while checking claim eligibility will appear here.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(prescriptionProvider.notifier).fetchPrescriptions(isRefresh: true);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
              itemCount: prescriptions.length + (pagination.hasNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == prescriptions.length) {
                  ref.read(prescriptionProvider.notifier).loadNextPage();
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)),
                    ),
                  );
                }
                return ContentWidth(child: _buildPrescriptionCard(context, prescriptions[index]));
              },
            ),
          );
        },
        loading: () => const LoadingState(message: 'Loading your prescriptions…'),
        error: (err, stack) => ErrorState(
          title: 'Couldn\'t load prescriptions',
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(prescriptionProvider),
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(BuildContext context, Prescription prescription) {
    final p = context.palette;
    final label = prescription.displayId;
    final isSelected = _selectedPrescriptionIds.contains(prescription.id);
    final hasFile = prescription.gridFsFileId != null && prescription.gridFsFileId!.trim().isNotEmpty;

    String cleanField(dynamic val) {
      if (val == null) return '---';
      final str = val.toString().trim();
      if (str.isEmpty ||
          str.toLowerCase() == 'none' ||
          str.toLowerCase() == 'null' ||
          str.toLowerCase().startsWith('unknown')) {
        return '---';
      }
      return str;
    }

    final hospitalDisplayName = cleanField(prescription.hospitalName);
    final patientDisplayName = cleanField(prescription.patientName);
    final doctorDisplayName = cleanField(prescription.doctorName);
    final rxNumDisplayName = cleanField(prescription.prescriptionNumber);
    final formattedVisitDate = prescription.visitDate != null
        ? DateFormat('dd MMM yyyy').format(prescription.visitDate!.toLocal())
        : '---';
    final fileNameDisplay = cleanField(prescription.originalFileName);
    final title = hospitalDisplayName == '---'
        ? (fileNameDisplay != '---' ? fileNameDisplay : 'Prescription / Medical Document')
        : hospitalDisplayName;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      color: isSelected ? p.primarySoft : null,
      borderColor: isSelected ? p.primary : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onLongPress: () => _enterSelectionMode(prescription.id),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(prescription.id);
            } else {
              if (hasFile) {
                context.push('/view-pdf/${prescription.gridFsFileId}?title=${prescription.displayId}');
              } else {
                _showManualPrescriptionDialog(context, prescription);
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
                          child: Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(prescription.id)),
                        ),
                      )
                    else ...[
                      IconTile(
                        icon: hasFile ? Icons.medication_outlined : Icons.edit_note_rounded,
                        tone: AppTone.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xxs,
                            children: [
                              StatusBadge(label: prescription.displayId, tone: AppTone.success, dense: true),
                              if (!hasFile)
                                const StatusBadge(
                                  label: 'Self-entered',
                                  tone: AppTone.neutral,
                                  icon: Icons.edit_outlined,
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
                          if (value == 'delete') _confirmDeleteSingle(prescription.id, label);
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
                      if (patientDisplayName != '---')
                        _MetaLine(icon: Icons.person_outline_rounded, label: 'Patient', value: patientDisplayName),
                      if (doctorDisplayName != '---')
                        _MetaLine(icon: Icons.medical_services_outlined, label: 'Doctor', value: doctorDisplayName),
                      if (rxNumDisplayName != '---')
                        _MetaLine(icon: Icons.tag_rounded, label: 'Prescription No.', value: rxNumDisplayName),
                      if (formattedVisitDate != '---')
                        _MetaLine(icon: Icons.calendar_today_outlined, label: 'Date', value: formattedVisitDate),
                      if (fileNameDisplay != '---')
                        _MetaLine(
                          icon: Icons.insert_drive_file_outlined,
                          label: 'File',
                          value: fileNameDisplay,
                          singleLine: true,
                        ),
                      if (prescription.createdAt != null)
                        _MetaLine(
                          icon: Icons.schedule_rounded,
                          label: 'Uploaded',
                          value: DateFormat('dd MMM yyyy, hh:mm a').format(prescription.createdAt!.toLocal()),
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
