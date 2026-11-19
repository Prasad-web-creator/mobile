import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;

  final List<String> _bulletPoints = [
    'I confirm that the uploaded documents belong to me or I have permission to use them.',
    'I understand that the analysis is for informational purposes only.',
    'I understand that the system does not submit insurance claims.',
    'I understand that the insurance provider makes the final approval decision.',
    'I agree that the generated report is only a reference.',
    'I consent to processing my uploaded documents for analysis.',
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Consent & Agreement'),
      ),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
            children: [
              const _StepHeader(current: 1, total: 3, label: 'Consent'),
              const SizedBox(height: AppSpacing.xl),
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
      bottomNavigationBar: BottomActionBar(
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
                      child: Text(
                        'I have read and agree to the Terms & Conditions.',
                        style: context.text.titleSmall,
                      ),
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
                child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancel')),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _agreed ? () => context.push('/upload') : null, // Go to upload options on success
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text('Continue', overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Visual-only progress indicator for the Consent → Prescription → Policy flow.
class _StepHeader extends StatelessWidget {
  final int current;
  final int total;
  final String label;

  const _StepHeader({required this.current, required this.total, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'STEP $current OF $total',
              style: context.text.labelSmall?.copyWith(color: p.primary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                '· $label',
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: p.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (int i = 1; i <= total; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current ? p.primary : p.border,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
