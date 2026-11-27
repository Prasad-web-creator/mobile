import 'package:flutter/widgets.dart';

import 'package:claimsupport/features/policies/presentation/screens/policy_list_screen.dart';
import 'package:claimsupport/features/prescriptions/presentation/screens/prescription_list_screen.dart';

enum DocumentsTab { prescriptions, policies }

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key, required this.tab});

  final DocumentsTab tab;

  static DocumentsTab tabFrom(String? value) =>
      value == 'policies' ? DocumentsTab.policies : DocumentsTab.prescriptions;

  @override
  Widget build(BuildContext context) =>
      tab == DocumentsTab.policies ? const PolicyListScreen() : const PrescriptionListScreen();
}
