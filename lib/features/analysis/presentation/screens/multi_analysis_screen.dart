import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';
import 'package:claimsupport/features/analysis/data/models/multi_analysis_session.dart';
import 'package:claimsupport/features/analysis/presentation/controllers/multi_analysis_controller.dart';
import 'package:claimsupport/features/analysis/presentation/widgets/clarification_dialog.dart';

/// Multi-policy analysis: one prescription, several policies, one row per policy.
class MultiAnalysisScreen extends ConsumerStatefulWidget {
  const MultiAnalysisScreen({super.key, this.resumeJobId, this.resumeSessionId});

  final String? resumeJobId;
  final String? resumeSessionId;

  @override
  ConsumerState<MultiAnalysisScreen> createState() => _MultiAnalysisScreenState();
}

class _MultiAnalysisScreenState extends ConsumerState<MultiAnalysisScreen> {
  bool _started = false;
  bool _dialogShowing = false;
  String? _answeringPolicyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_started || !mounted) return;
    _started = true;
    if (widget.resumeJobId case final jobId?) {
      await ref.read(multiAnalysisJobProvider.notifier).resumeJob(jobId);
      return;
    }
    if (widget.resumeSessionId case final sessionId?) {
      await ref.read(multiAnalysisJobProvider.notifier).resumeSession(sessionId);
      return;
    }

    final prefs = SharedPrefs.instance;
    final prescriptionPath = prefs.getString('prescription_path');
    final rawIds = prefs.getString('policy_ids');

    List<String> policyIds = [];
    if (rawIds != null && rawIds.isNotEmpty) {
      try {
        policyIds = (jsonDecode(rawIds) as List).map((e) => e.toString()).toList();
      } catch (e) {
        developer.log('[MultiAnalysisScreen] Could not decode policy_ids: $e');
      }
    }

    if (prescriptionPath == null || policyIds.isEmpty) {
      developer.log('[MultiAnalysisScreen] Missing prescription or policy selection');
      return;
    }

    final draftJob = prefs.getString(analysisDraftKey);
    await ref
        .read(multiAnalysisJobProvider.notifier)
        .startAnalysis(MultiAnalysisParams(prescriptionPath: prescriptionPath, policyIds: policyIds));
    if (mounted && draftJob != null && ref.read(multiAnalysisJobProvider).hasValue) {
      context.pushReplacement('/check/processing/${Uri.encodeComponent(draftJob)}');
    }
  }

  /// Show the questions of [target] (when the user taps that policy's
  /// "Answer question"), or of the first policy that is waiting.
  void _maybeShowClarification(MultiAnalysisSession session, {PolicyAnalysisResult? target}) {
    if (_dialogShowing || !mounted || session.status == 'running') return;
    final pending = (target != null && target.isWaitingForUser && target.questions.isNotEmpty)
        ? target
        : session.pendingClarification;
    if (pending == null || (target == null && pending.policyId == _answeringPolicyId)) return;

    _dialogShowing = true;
    _answeringPolicyId = pending.policyId;

    // With several policies in flight, say plainly which one is asking (by its
    // number in this comparison) and which others still have questions.
    final othersWaiting = session.policyAnalyses
        .where((p) => p.isWaitingForUser && p.policyId != pending.policyId)
        .map((p) => p.queueNumber)
        .toList();
    final queueLabel = othersWaiting.isEmpty
        ? null
        : 'Next: ${othersWaiting.map((n) => 'Policy $n').join(', ')} '
              '${othersWaiting.length == 1 ? 'also has' : 'also have'} questions.';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ClarificationDialog(
        clarificationData: {'questions': pending.questions},
        contextLabel: pending.displayName,
        contextSubLabel: pending.insuranceCompany,
        queueLabel: queueLabel,
        // Numbers only mean something when several policies are compared.
        policyNumber: (session.policyCount > 1 && pending.queueNumber > 0) ? pending.queueNumber : null,
        policyCount: session.policyCount,
        onSubmit: (answers) {
          Navigator.of(dialogContext).pop();
          _dialogShowing = false;
          ref.read(multiAnalysisJobProvider.notifier).submitPolicyAnswers(pending.policyId, answers);
        },
        onCancel: () {
          Navigator.of(dialogContext).pop();
          _dialogShowing = false;
        },
      ),
    ).then((_) => _dialogShowing = false);
  }

  void _openReport(String reportId) => context.push('/summary/$reportId');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiAnalysisJobProvider);

    ref.listen(multiAnalysisJobProvider, (previous, next) {
      next.whenData((session) {
        if (_answeringPolicyId != null) {
          final answered = session.policyAnalyses.where((p) => p.policyId == _answeringPolicyId).firstOrNull;
          if (answered != null && !answered.isWaitingForUser) {
            _answeringPolicyId = null;
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Use the state as it is NOW, not the snapshot this callback was
          // scheduled with: if the user submitted answers in between, that
          // snapshot still shows the question and would open it again.
          final latest = ref.read(multiAnalysisJobProvider).asData?.value;
          if (latest != null) _maybeShowClarification(latest);
        });
      });
    });

    return FlowShell(
      title: 'Policy Comparison',
      onClose: () => context.go('/dashboard'),
      action: (state.asData?.value.canCancel ?? false)
          ? TextButton(
              onPressed: () async {
                try {
                  await ref.read(multiAnalysisJobProvider.notifier).cancelAnalysis();
                } catch (error) {
                  if (!context.mounted) return;
                  showAppSnackBar(context, friendlyErrorMessage(error), tone: AppTone.warning);
                }
              },
              child: const Text('Cancel analysis'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: state.when(
          loading: () => _buildLoading(),
          error: (error, _) => _buildError(error),
          data: (session) => _buildSession(session),
        ),
      ),
    );
  }

  /// Shown only while the session itself is being created — a single request,
  /// with genuinely nothing to measure yet. Once it returns, every indicator on
  /// this screen is driven by steps the backend reports as finished.
  Widget _buildLoading() {
    return const LoadingState(message: 'Connecting to the server and preparing analysis…');
  }

  /// Session-wide progress: steps the backend has actually completed out of the
  /// steps it plans to run. No value here is estimated or time-driven, and when
  /// the server reports no counts the bar falls back to indeterminate rather
  /// than showing a number it cannot stand behind.
  Widget _buildProgressCard(MultiAnalysisSession session) {
    final p = context.palette;
    final t = context.text;
    final progress = session.progress;
    final fraction = progress.fraction;
    final blocked = session.isBlockedOnUser;
    final accent = blocked ? p.warning.fg : p.primary;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      borderColor: blocked ? p.warning.border : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(blocked ? Icons.help_outline_rounded : Icons.sync_rounded, size: 20, color: accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  progress.label.isNotEmpty ? progress.label : (blocked ? 'Waiting for your answer' : 'Working…'),
                  style: t.titleSmall,
                ),
              ),
              if (progress.isKnown) ...[
                const SizedBox(width: AppSpacing.xs),
                _AnimatedPercentText(value: fraction ?? 0, color: accent),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _AnimatedProgressBar(value: fraction, height: 6, radius: 4, color: accent, backgroundColor: p.surfaceMuted),
          const SizedBox(height: AppSpacing.xs),
          Text(
            progress.isKnown
                ? '${progress.completedSteps} of ${progress.totalSteps} steps done · '
                      '${session.completedCount}/${session.policyCount} '
                      '${session.policyCount == 1 ? 'policy' : 'policies'} finished'
                : 'Following the analysis…',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Analysis could not be completed',
      message: friendlyErrorMessage(error),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () {
              // Same prescription and policies as before.
              _started = false;
              _start();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(onPressed: () => context.go('/dashboard'), child: const Text('Back to Dashboard')),
        ],
      ),
    );
  }

  Widget _buildSession(MultiAnalysisSession session) {
    if (session.status == 'failed' &&
        session.errorMessage.isNotEmpty &&
        !session.policyAnalyses.any((policy) => policy.hasReport || policy.errorMessage.isNotEmpty)) {
      return EmptyState(
        icon: Icons.info_outline_rounded,
        title: 'Analysis ended',
        message: session.errorMessage,
        action: OutlinedButton(onPressed: () => context.go('/dashboard'), child: const Text('Back to Home')),
      );
    }
    final p = context.palette;
    final t = context.text;

    final diagnosis = session.prescription['diagnosis']?.toString() ?? '';
    final visitDate = session.prescription['visitDate']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Prescription header ──────────────────────────────────────
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardTitle(title: 'Prescription', icon: Icons.description_outlined),
                    if (diagnosis.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(diagnosis, style: t.bodyLarge),
                    ],
                    if (visitDate.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(Icons.event_outlined, size: 14, color: p.textTertiary),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(child: Text(visitDate, style: t.bodySmall)),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Divider(height: 1, color: p.border),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Analyzed against ${session.policyCount} '
                      '${session.policyCount == 1 ? 'policy' : 'policies'}',
                      style: t.labelMedium,
                    ),
                  ],
                ),
              ),

              // Only while something is actually outstanding — a finished comparison
              // has no progress left to report.
              if (session.isWorking || session.isBlockedOnUser) _buildProgressCard(session),

              const SectionHeader(title: 'Policies'),

              ...session.policyAnalyses.map((policy) => _buildPolicyCard(session, policy)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyCard(MultiAnalysisSession session, PolicyAnalysisResult policy) {
    final p = context.palette;
    final t = context.text;
    final waiting = policy.isWaitingForUser;
    final showAnswer = policy.isWaitingForUser && session.status != 'running';
    final showRetry = policy.isFailed;
    // Reports open only once the whole comparison has finished: every
    // policy completed, in manual review, or failed. A policy still
    // running or waiting for an answer keeps all reports hidden.
    final showReport = policy.hasReport && session.isSettled;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: waiting ? p.warning.fg : p.border, width: waiting ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (policy.queueNumber > 0) ...[
                      _QueueNumberBadge(number: policy.queueNumber, color: waiting ? p.warning.fg : p.primary),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(policy.queueLabel, style: t.labelSmall),
                          const SizedBox(height: 2),
                          Text(policy.displayName, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (policy.insuranceCompany.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(policy.insuranceCompany, style: t.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerLeft, child: _buildStatusChip(policy)),

                if (policy.isFailed && policy.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  InfoBanner(
                    tone: AppTone.danger,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    child: Text(
                      friendlyErrorMessage(policy.errorMessage),
                      style: t.bodySmall?.copyWith(color: p.textPrimary),
                    ),
                  ),
                ],

                // What this policy is doing, and how far through its own steps it is.
                if (policy.isRunning) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _AnimatedProgressBar(
                    value: policy.stepProgress,
                    height: 4,
                    radius: 3,
                    color: p.primary,
                    backgroundColor: p.surfaceMuted,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    policy.totalSteps > 0
                        ? '${policy.progressLabel} · step ${policy.completedSteps + 1} of ${policy.totalSteps}'
                        : policy.progressLabel,
                    style: t.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (showAnswer || showRetry || showReport) ...[
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: AppSpacing.xs,
                children: [
                  if (showAnswer)
                    TextButton.icon(
                      onPressed: () => _maybeShowClarification(session, target: policy),
                      icon: const Icon(Icons.help_outline_rounded, size: 18),
                      label: const Text('Answer question'),
                    ),
                  if (showRetry)
                    TextButton.icon(
                      onPressed: () => ref.read(multiAnalysisJobProvider.notifier).retryPolicy(policy.policyId),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(foregroundColor: p.warning.fg),
                    ),
                  if (showReport)
                    TextButton.icon(
                      onPressed: () => _openReport(policy.reportId),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('View report'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(PolicyAnalysisResult policy) {
    AppTone tone;
    IconData icon;
    if (policy.isFailed) {
      tone = AppTone.danger;
      icon = Icons.error_outline_rounded;
    } else if (policy.isWaitingForUser) {
      tone = AppTone.warning;
      icon = Icons.help_outline_rounded;
    } else if (policy.status == 'manual_review_required') {
      tone = AppTone.warning;
      icon = Icons.hourglass_top_rounded;
    } else if (policy.status == 'completed') {
      final lower = policy.overallStatus.toLowerCase();
      if (lower.contains('not covered') || lower.contains('rejected')) {
        tone = AppTone.danger;
        icon = Icons.cancel_outlined;
      } else if (lower.contains('verification')) {
        tone = AppTone.verify;
        icon = Icons.fact_check_outlined;
      } else if (lower.contains('partial') || lower.contains('review')) {
        tone = AppTone.warning;
        icon = Icons.rule_rounded;
      } else {
        tone = AppTone.success;
        icon = Icons.check_circle_outline_rounded;
      }
    } else {
      tone = AppTone.neutral;
      icon = Icons.schedule_rounded;
    }

    return StatusBadge(label: policy.statusLabel, tone: tone, icon: icon);
  }
}

// Round badge with a policy's temporary number in this comparison.
class _QueueNumberBadge extends StatelessWidget {
  const _QueueNumberBadge({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withAlpha(context.isDark ? 45 : 26),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        '$number',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// A progress bar that travels to each new value instead of snapping to it.
///
/// The target is always the real, server-reported fraction — the animation only
/// covers the distance between two true readings, so the bar never moves ahead
/// of the work. A null value means the backend reported no step counts and the
/// bar stays indeterminate rather than showing an invented position.
class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({
    required this.value,
    required this.height,
    required this.radius,
    required this.color,
    required this.backgroundColor,
  });

  final double? value;
  final double height;
  final double radius;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bar = value == null
        ? LinearProgressIndicator(
            minHeight: height,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          )
        : TweenAnimationBuilder<double>(
            // Re-targeting mid-flight continues from where the bar currently
            // is, so consecutive updates read as one continuous movement.
            tween: Tween<double>(end: value!.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => LinearProgressIndicator(
              value: animated,
              minHeight: height,
              backgroundColor: backgroundColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          );

    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: bar);
  }
}

/// The percentage counts up in step with the bar, so the two never disagree.
class _AnimatedPercentText extends StatelessWidget {
  const _AnimatedPercentText({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(
        '${(animated * 100).round()}%',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
