import 'package:claimsupport/core/design/widgets/app_illustration.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/features/documents/data/document_fields.dart';
import 'package:claimsupport/features/documents/data/document_detail_fields.dart';
import 'package:claimsupport/features/documents/presentation/document_summary.dart';
import 'package:claimsupport/features/documents/presentation/saved_list_feedback.dart';
import 'package:claimsupport/features/documents/presentation/view_document_button.dart';
import 'package:claimsupport/features/documents/presentation/screens/saved_document_list.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PrescriptionListScreen extends ConsumerWidget {
  const PrescriptionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prescriptionProvider);
    final notifier = ref.read(prescriptionProvider.notifier);
    return SavedDocumentList<Prescription>(
      title: 'Prescriptions',
      onAdd: () => context.push('/check/new?add=prescription'),
      singular: 'prescription',
      page: state.value ?? notifier.cachedPage,
      isLoading: state.isLoading,
      error: state.error,
      describe: DocumentSummary.prescription,
      createdAt: (prescription) => prescription.createdAt,
      idOf: (prescription) => prescription.id,
      onOpen: _showPrescription,
      onRefresh: () => notifier.fetchPrescriptions(isRefresh: true),
      fetchPage: notifier.fetchAndKeepPage,
      fetchFilterPage: notifier.fetchPage,
      filters: {'Uploaded': (record) => !record.isManual, 'Manual': (record) => record.isManual},
      onDelete: notifier.deletePrescriptions,
    );
  }

  void _showPrescription(BuildContext context, Prescription record, DocumentSummary summary) {
    final fields = prescriptionDetailFields(record);
    final fileId = documentText(record.gridFsFileId);
    AppSheet.show<void>(
      context: context,
      title: summary.title,
      showClose: true,
      artwork: AppIllustrationKind.prescription,
      footerBuilder: fileId == null ? null : (_) => ViewDocumentButton(fileId: fileId, title: summary.title),
      bodyBuilder: (context) => AppSheetList(
        rows: [
          for (final (label, value) in fields)
            AppSheetKeyValue(label: label, value: value),
          if (record.items.isNotEmpty) AppSheetFieldList(label: 'Items', values: record.items),
          if (fields.isEmpty && record.items.isEmpty) const SavedListMessage('No extracted prescription details yet.'),
        ],
      ),
    );
  }
}
