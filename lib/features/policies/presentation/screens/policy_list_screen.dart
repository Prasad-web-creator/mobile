import 'package:claimsupport/core/design/widgets/app_illustration.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/features/documents/data/document_fields.dart';
import 'package:claimsupport/features/documents/data/document_detail_fields.dart';
import 'package:claimsupport/features/documents/presentation/document_summary.dart';
import 'package:claimsupport/features/documents/presentation/saved_list_feedback.dart';
import 'package:claimsupport/features/documents/presentation/view_document_button.dart';
import 'package:claimsupport/features/documents/presentation/screens/saved_document_list.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PolicyListScreen extends ConsumerWidget {
  const PolicyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(policiesProvider);
    final notifier = ref.read(policiesProvider.notifier);
    return SavedDocumentList<Policy>(
      title: 'Policies',
      singular: 'policy',
      page: state.value ?? notifier.cachedPage,
      isLoading: state.isLoading,
      error: state.error,
      describe: DocumentSummary.policy,
      createdAt: (policy) => policy.createdAt,
      idOf: (policy) => policy.id,
      onOpen: _showPolicy,
      onRefresh: () => notifier.fetchPolicies(isRefresh: true),
      fetchPage: notifier.fetchAndKeepPage,
      onDelete: notifier.deletePolicies,
    );
  }

  void _showPolicy(BuildContext context, Policy policy, DocumentSummary summary) {
    final fields = policyDetailFields(policy);
    final fileId = documentText(policy.gridFsFileId);
    AppSheet.show<void>(
      context: context,
      title: summary.title,
      showClose: true,
      artwork: AppIllustrationKind.policy,
      footerBuilder: fileId == null ? null : (_) => ViewDocumentButton(fileId: fileId, title: summary.title),
      bodyBuilder: (context) => AppSheetList(
        rows: [
          for (final (label, value) in fields)
            AppSheetKeyValue(label: label, value: value, monospace: label == 'Policy number'),
          if (policy.insuredMembers.isNotEmpty) AppSheetFieldList(label: 'Members', values: policy.insuredMembers),
          if (fields.isEmpty && policy.insuredMembers.isEmpty)
            const SavedListMessage('No extracted policy details yet.'),
        ],
      ),
    );
  }
}
