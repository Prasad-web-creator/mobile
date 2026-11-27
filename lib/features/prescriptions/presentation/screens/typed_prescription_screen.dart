import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/features/analysis/data/repositories/new_check_repository.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TypedPrescriptionScreen extends ConsumerStatefulWidget {
  const TypedPrescriptionScreen({super.key});

  @override
  ConsumerState<TypedPrescriptionScreen> createState() => _TypedPrescriptionScreenState();
}

class _TypedPrescriptionScreenState extends ConsumerState<TypedPrescriptionScreen> {
  final _text = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(newCheckRepositoryProvider);
      final saved = await repository.saveTypedPrescription(text);
      if (!mounted) return;
      ref.invalidate(checkTreatmentsProvider);
      ref.invalidate(prescriptionProvider);
      ref.invalidate(dashboardStatsProvider);
      context.pop(saved);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't save your prescription. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FlowShell(
      title: 'Type it in',
      onClose: () => context.pop(),
      backButton: true,
      body: ListView(
        padding: const EdgeInsets.all(DsSpace.screenPadding),
        children: [
          Text(
            'Write the illness, symptoms, tests or surgery the doctor advised. A few words is enough.',
            style: AppTextStyles.bodyStrong.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DsSpace.s16),
          TextField(
            controller: _text,
            readOnly: _saving,
            minLines: 7,
            maxLines: 10,
            onChanged: (_) => setState(() {}),
            style: AppTextStyles.bodyStrong.copyWith(color: colors.textPrimary, height: 1.5),
            decoration: InputDecoration(
              labelText: 'Treatment',
              alignLabelWithHint: true,
              errorText: _error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(DsShape.radiusMd)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DsShape.radiusMd),
                borderSide: BorderSide(color: colors.buttonPrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: DsSpace.s12),
          Text(
            "We'll check it as if you're admitted to hospital today.",
            style: AppTextStyles.label.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
      bottomAction: AppButton(
        label: 'Save prescription',
        busy: _saving,
        onPressed: _saving || _text.text.trim().isEmpty ? null : _save,
      ),
    );
  }
}
