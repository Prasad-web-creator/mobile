import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/analysis/presentation/controllers/analysis_controller.dart';
import 'package:claimsupport/features/analysis/presentation/widgets/clarification_dialog.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> with SingleTickerProviderStateMixin {
  bool _hasError = false;
  String _errorMessage = '';
  int _currentStage = 0;
  late AnimationController _pulseController;

  // Guard: prevent showing the dialog more than once per state update
  bool _dialogShowing = false;
  // Guard: prevent navigating to summary more than once
  bool _navigatedToSummary = false;
  bool _isImageBased = false;
  // True once the user has submitted at least one clarification answer.
  bool _answersSubmitted = false;
  static const int _reanalysisStage = 8;

  final List<String> _stageLabels = [
    'Validating Documents',
    'Extracting PDF Text',
    'Cleaning & Normalizing',
    'Extracting Policy Data',
    'Extracting Prescription Data',
    'Validating Extracted Data',
    'Running Business Rules',
    'Coverage Analysis',
    'Re-analyzing with your answers...',
    'Generating Report',
    'Loading Coverage Summary...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    try {
      final prefs = SharedPrefs.instance;
      final rxImageBased = prefs.getBool('prescription_is_image_based') ?? false;
      final policyImageBased = prefs.getBool('policy_is_image_based') ?? false;
      _isImageBased = rxImageBased || policyImageBased;
    } catch (_) {}

    _simulateProgress();

    // Start the analysis job
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = SharedPrefs.instance;
      final prescriptionPath = prefs.getString('prescription_path');
      final policyPath = prefs.getString('policy_path');
      final policyId = policyPath != null ? null : prefs.getString('policy_id');

      if (prescriptionPath != null && (policyPath != null || policyId != null)) {
        final params = AnalysisParams(prescriptionPath: prescriptionPath, policyPath: policyPath, policyId: policyId);
        ref.read(analysisJobProvider.notifier).startAnalysis(params);
      } else {
        developer.log('[AnalysisScreen] ERROR: Missing prescription or policy path/id');
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _simulateProgress() async {
    // Simulate stage progression for visual feedback (stops at stage 7 to leave room for re-analysis)
    for (int i = 0; i <= 7; i++) {
      await Future.delayed(const Duration(milliseconds: 2200));
      if (!mounted || _hasError) return;
      setState(() {
        _currentStage = i + 1;
      });
    }
  }

  void _showClarificationDialog(Map<String, dynamic> data) {
    if (_dialogShowing || !mounted) return;
    _dialogShowing = true;
    developer.log(
      '[AnalysisScreen] Showing clarification dialog. sessionId=${data['sessionId']}, questions=${(data['questions'] as List?)?.length ?? 0}',
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ClarificationDialog(
        clarificationData: data,
        onSubmit: (answers) {
          Navigator.of(dialogContext).pop();
          _dialogShowing = false;
          // Advance to re-analysis stage visually
          if (mounted) {
            setState(() {
              if (answers.values.any(_isAnswered)) _answersSubmitted = true;
              _currentStage = 8; // "Re-analyzing with your answers..."
            });
          }
          final sessionId = data['sessionId'] as String;
          developer.log('[AnalysisScreen] Calling submitAnswers for sessionId=$sessionId');
          ref.read(analysisJobProvider.notifier).submitAnswers(sessionId, answers);
        },
        onCancel: () {
          developer.log('[AnalysisScreen] Clarification cancelled by user');
          Navigator.of(dialogContext).pop();
          _dialogShowing = false;
          ref.read(analysisJobProvider.notifier).cancelAnalysis();
          if (mounted) context.go('/dashboard');
        },
      ),
    ).then((_) {
      // Reset flag if dialog was dismissed by other means
      _dialogShowing = false;
    });
  }

  void _navigateToSummary(Map<String, dynamic> data) {
    if (_navigatedToSummary || !mounted) return;
    _navigatedToSummary = true;
    developer.log('[AnalysisScreen] Analysis complete! Navigating to summary. status=${data['status']}');

    final prefs = SharedPrefs.instance;
    prefs.setString('analysis_result', jsonEncode(data));

    setState(() {
      _currentStage = _stageLabels.length;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        context.pushReplacement('/summary');
      }
    });
  }

  void _retryAnalysis() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _currentStage = 0;
      _navigatedToSummary = false;
    });
    _simulateProgress();
    final prefs = SharedPrefs.instance;
    final prescriptionPath = prefs.getString('prescription_path');
    final policyPath = prefs.getString('policy_path');
    final policyId = policyPath != null ? null : prefs.getString('policy_id');
    if (prescriptionPath != null && (policyPath != null || policyId != null)) {
      final params = AnalysisParams(prescriptionPath: prescriptionPath, policyPath: policyPath, policyId: policyId);
      ref.read(analysisJobProvider.notifier).startAnalysis(params);
    }
  }

  static bool _isAnswered(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is Iterable) return v.isNotEmpty;
    return true;
  }

  Widget _buildContent(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final isComplete = _currentStage >= _stageLabels.length;
    // The re-analysis stage is only listed when clarification answers were given.
    final visibleLabels = [
      for (int i = 0; i < _stageLabels.length; i++)
        if (i != _reanalysisStage || _answersSubmitted) _stageLabels[i],
    ];
    final visibleStage = (!_answersSubmitted && _currentStage > _reanalysisStage) ? _currentStage - 1 : _currentStage;
    final total = visibleLabels.length;
    final stepNumber = (visibleStage + 1).clamp(1, total);

    final ToneColors heroTone = _hasError ? p.danger : (isComplete ? p.success : p.info);
    final IconData heroIcon = _hasError
        ? Icons.error_outline_rounded
        : (isComplete ? Icons.check_circle_rounded : Icons.manage_search_rounded);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xxl, AppSpacing.page, AppSpacing.xxl),
        child: ContentWidth(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status icon (very subtle pulse while working)
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final working = !_hasError && !isComplete;
                    return Transform.scale(scale: working ? 1.0 + (_pulseController.value * 0.04) : 1.0, child: child);
                  },
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: heroTone.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: heroTone.border),
                    ),
                    child: Icon(heroIcon, size: 40, color: heroTone.fg),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                _hasError ? 'Analysis Failed' : (isComplete ? 'Analysis Complete!' : 'Analyzing...'),
                textAlign: TextAlign.center,
                style: t.headlineSmall?.copyWith(color: _hasError ? p.danger.fg : p.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Subtitle
              Text(
                _hasError
                    ? 'Something went wrong during the analysis.'
                    : 'Our system is reading your documents and cross-referencing coverage.',
                textAlign: TextAlign.center,
                style: t.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Image-based PDF notification
              if (!_hasError && _isImageBased && !isComplete) ...[
                const InfoBanner(
                  tone: AppTone.info,
                  icon: Icons.timer_outlined,
                  message: 'Your uploaded PDF is image-based, so it may take some time. Please stay here.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Pipeline progress
              if (!_hasError)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Analysis progress', style: t.titleSmall)),
                          Text(
                            isComplete ? 'Done' : 'Step $stepNumber of $total',
                            style: t.labelMedium?.copyWith(color: isComplete ? p.success.fg : p.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: AppRadius.pillAll,
                        child: LinearProgressIndicator(
                          // Stages are indicative, so the bar stays indeterminate until done.
                          value: isComplete ? 1 : null,
                          minHeight: 4,
                          color: isComplete ? p.success.fg : p.primary,
                          backgroundColor: p.surfaceMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ...List.generate(total, (index) {
                        return _StageRow(
                          label: visibleLabels[index],
                          isCompleted: index < visibleStage,
                          isActive: index == visibleStage,
                          isLast: index == total - 1,
                        );
                      }),
                    ],
                  ),
                ),

              // Error display
              if (_hasError) ...[
                InfoBanner(
                  tone: AppTone.danger,
                  title: 'We couldn\'t complete the analysis',
                  message: friendlyErrorMessage(_errorMessage),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: 'Retry Analysis', icon: Icons.refresh_rounded, onPressed: _retryAnalysis),
                const SizedBox(height: AppSpacing.xs),
                SecondaryButton(label: 'Return to Dashboard', onPressed: () => context.go('/dashboard')),
              ] else if (!isComplete) ...[
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16, color: p.textTertiary),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Please keep this screen open',
                        textAlign: TextAlign.center,
                        style: t.labelMedium?.copyWith(color: p.textTertiary),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? prescriptionPath;
    String? policyPath;
    String? policyId;
    try {
      final prefs = SharedPrefs.instance;
      prescriptionPath = prefs.getString('prescription_path');
      policyPath = prefs.getString('policy_path');
      policyId = policyPath != null ? null : prefs.getString('policy_id');
    } catch (e) {
      developer.log('[AnalysisScreen] SharedPrefs error in build: $e');
    }

    if (prescriptionPath == null || (policyPath == null && policyId == null)) {
      return FlowShell(
        title: 'Coverage Analysis',
        onClose: () => context.go('/dashboard'),
        body: SafeArea(
          child: EmptyState(
            icon: Icons.upload_file_outlined,
            title: 'Missing uploaded files or policy selection.',
            message: 'Please start a new analysis and add your prescription and policy.',
            action: FilledButton(
              onPressed: () => context.go('/dashboard'),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
              child: const Text('Return to Dashboard'),
            ),
          ),
        ),
      );
    }

    // Watch the provider state — this fires on every state change
    final analysisState = ref.watch(analysisJobProvider);

    developer.log(
      '[AnalysisScreen] Build: isLoading=${analysisState.isLoading}, hasError=${analysisState.hasError}, hasValue=${analysisState.hasValue}',
    );

    // ── Handle state transitions via post-frame callbacks ───────────────
    analysisState.whenOrNull(
      data: (data) {
        final status = (data['status'] as String? ?? '').toLowerCase();
        final overallStatus = (data['overallStatus'] as String? ?? '').toLowerCase();
        final isComplete =
            status == 'complete' ||
            status == 'completed' ||
            status == 'manual_review_required' ||
            overallStatus.startsWith('invalid') ||
            data.containsKey('documentValidity') ||
            data.containsKey('overallStatus');

        developer.log(
          '[AnalysisScreen] State data received. status=$status, overallStatus=$overallStatus, isComplete=$isComplete',
        );

        if (status == 'needs_clarification' && !_dialogShowing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_dialogShowing) {
              _showClarificationDialog(data);
            }
          });
        } else if (isComplete && !_navigatedToSummary) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_navigatedToSummary) {
              _navigateToSummary(data);
            }
          });
        }
      },
      error: (error, st) {
        developer.log('[AnalysisScreen] Analysis request failed.');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasError) {
            setState(() {
              _hasError = true;
              _errorMessage = error.toString();
            });
          }
        });
      },
    );

    // Clear error state if it was fixed
    if (!analysisState.hasError && _hasError && !analysisState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasError = false;
            _errorMessage = '';
          });
        }
      });
    }

    return FlowShell(title: 'Coverage Analysis', onClose: () => context.go('/dashboard'), body: _buildContent(context));
  }
}

/// One row of the analysis stepper: done / active / pending, joined by a connector line.
class _StageRow extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final bool isActive;
  final bool isLast;

  const _StageRow({required this.label, required this.isCompleted, required this.isActive, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget marker;
    if (isCompleted) {
      marker = Icon(Icons.check_circle_rounded, color: p.success.fg, size: 22);
    } else if (isActive) {
      marker = Padding(
        padding: const EdgeInsets.all(2),
        child: CircularProgressIndicator(strokeWidth: 2.4, color: p.primary),
      );
    } else {
      marker = Icon(Icons.radio_button_unchecked_rounded, color: p.borderStrong, size: 22);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                SizedBox(width: 22, height: 22, child: marker),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: isCompleted ? p.success.border : p.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : AppSpacing.md),
              child: Text(
                label,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isCompleted ? p.textSecondary : (isActive ? p.textPrimary : p.textTertiary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
