import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;
  bool _saving = false;
  late final String _requestId = _newRequestId();

  String _newRequestId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _accept() async {
    setState(() => _saving = true);
    try {
      final id = await AnalysisRepository().createJob(_requestId);
      final prefs = SharedPrefs.instance;
      if (prefs.getString(analysisDraftKey) != id) {
        await prefs.remove('prescription_path');
        await prefs.remove('policy_ids');
      }
      await prefs.setString(analysisDraftKey, id);
      if (mounted) context.push('/upload');
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save consent. Please try again.', tone: AppTone.warning);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  final List<String> _bulletPoints = [
    'I confirm that the uploaded documents belong to me or I have permission to use them.',
    'I understand that the analysis is for informational purposes only.',
    'I understand that the system does not submit insurance claims.',
    'I understand that the insurance provider makes the final approval decision.',
    'I agree that the generated report is only a reference.',
    'I agree that Policy Pal may store my uploaded documents, read them with OCR, and send extracted text and any details I enter to Google Gemini for coverage analysis.',
  ];

  static const List<IconData> _bulletIcons = [
    Icons.badge_outlined,
    Icons.info_outline_rounded,
    Icons.send_outlined,
    Icons.verified_user_outlined,
    Icons.description_outlined,
    Icons.lock_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    void close() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }

    return FlowShell(
      title: 'Consent & Agreement',
      step: 1,
      stepCount: 3,
      onClose: close,
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
            children: [
              Text('Before we begin', style: context.text.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Please review and accept the Terms & Conditions before the system analyzes your uploaded documents.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CardTitle(title: 'Terms of use', icon: Icons.gavel_rounded),
                    const SizedBox(height: AppSpacing.sm),
                    for (int i = 0; i < _bulletPoints.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: p.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_bulletIcons[i % _bulletIcons.length], size: 20, color: p.textTertiary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _bulletPoints[i],
                                style: context.text.bodyMedium?.copyWith(color: p.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: _agreed ? p.primarySoft : p.surfaceMuted,
            borderRadius: AppRadius.mdAll,
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: () => setState(() => _agreed = !_agreed),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: _agreed ? p.primary.withAlpha(90) : p.border),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (value) {
                        setState(() {
                          _agreed = value ?? false;
                        });
                      },
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text('I have read and agree to the Terms & Conditions.', style: context.text.titleSmall),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              Expanded(
                child: AppButton(label: 'Cancel', style: AppButtonStyle.secondary, onPressed: close),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'Continue',
                  onPressed: _agreed && !_saving ? _accept : null,
                  icon: AppIcons.caretRight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
