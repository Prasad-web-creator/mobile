import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_design_surface.dart';
import 'package:claimsupport/core/design/widgets/app_illustration.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/features/analysis/data/models/multi_analysis_session.dart';
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';
import 'package:claimsupport/features/analysis/data/repositories/new_check_repository.dart';
import 'package:claimsupport/features/analysis/presentation/widgets/analysis_exit_guard.dart';
import 'package:claimsupport/features/analysis/presentation/widgets/clarification_dialog.dart';
import 'package:claimsupport/features/checks/presentation/check_completion_monitor.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';

const _finished = {'completed', 'partial', 'manual_review_required'};
const _stopped = {'failed', 'cancelled', 'expired', 'created'};
const _pollInterval = Duration(seconds: 2);

class CheckProcessingScreen extends ConsumerStatefulWidget {
  const CheckProcessingScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<CheckProcessingScreen> createState() => _CheckProcessingScreenState();
}

class _CheckProcessingScreenState extends ConsumerState<CheckProcessingScreen> with WidgetsBindingObserver {
  late final VoidCallback _viewClosed;
  late final VoidCallback _removeExitGuard;
  Timer? _pollTimer;
  Future<bool>? _exitRequest;
  String? _status;
  PolicyAnalysisResult? _question;
  bool _submitting = false;
  bool _disconnected = false;
  bool _answerFailed = false;
  bool _foreground = true;
  bool _tracking = false;
  bool _backgroundedDuringCheck = false;
  bool _cancelling = false;
  bool _cancelFailed = false;
  int _readGeneration = 0;

  bool get _canLeave => _stopped.contains(_status) || _finished.contains(_status);

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _foreground = !const {
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    }.contains(binding.lifecycleState);
    _backgroundedDuringCheck = !_foreground;
    final id = widget.jobId;
    _removeExitGuard = registerAnalysisExitGuard(ref, id, _confirmExit);
    final monitor = ref.read(checkCompletionMonitorProvider.notifier);
    _viewClosed = () => monitor.setProcessingView(id, false);
    binding.addPostFrameCallback((_) {
      if (!mounted) return;
      monitor.setProcessingView(id, true);
      unawaited(_read());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeExitGuard();
    _pollTimer?.cancel();
    scheduleMicrotask(_viewClosed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    final visible = state == AppLifecycleState.resumed;
    if (visible == _foreground) return;
    _foreground = visible;
    if (visible) {
      if (_backgroundedDuringCheck && !_canLeave) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _foreground) unawaited(_confirmExit());
        });
      } else {
        unawaited(_read());
      }
      _backgroundedDuringCheck = false;
    } else {
      _backgroundedDuringCheck = !_canLeave;
      _readGeneration++;
      _pollTimer?.cancel();
    }
  }

  Future<void> _leave({bool goHome = false}) async {
    if (!await _confirmExit() || !mounted) return;
    if (!goHome && context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  Future<bool> _confirmExit() {
    if (_canLeave) return Future.value(true);
    return _exitRequest ??= _askToStop().then((stopped) {
      _exitRequest = null;
      if (mounted && !stopped) unawaited(_read());
      return stopped;
    });
  }

  Future<bool> _askToStop() async {
    _pollTimer?.cancel();
    _readGeneration++;
    if (!await confirmStoppingAnalysis(context) || !mounted) return false;
    setState(() {
      _cancelling = true;
      _cancelFailed = false;
    });
    try {
      await ref.read(newCheckRepositoryProvider).cancelJob(widget.jobId);
      if (!mounted) return true;
      setState(() {
        _status = 'cancelled';
        _question = null;
        _disconnected = false;
        _answerFailed = false;
      });
      ref.read(checkCompletionMonitorProvider.notifier).acknowledge(widget.jobId);
      ref.invalidate(homeChecksProvider);
      ref.invalidate(dashboardStatsProvider);
      return true;
    } catch (_) {
      if (mounted) setState(() => _cancelFailed = true);
      return false;
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _read() async {
    _pollTimer?.cancel();
    if (_submitting || !_foreground || _exitRequest != null) return;
    final generation = ++_readGeneration;
    try {
      final job = await ref.read(newCheckRepositoryProvider).readJob(widget.jobId);
      if (!mounted || generation != _readGeneration) return;
      final status = job['status'] as String? ?? 'queued';
      final session = MultiAnalysisSession.fromJson(AnalysisRepository.jobSession(job));
      setState(() {
        _status = status;
        _question = session.pendingClarification;
        _disconnected = false;
      });
      if (_finished.contains(status)) {
        ref.read(checkCompletionMonitorProvider.notifier).acknowledge(widget.jobId);
        context.pushReplacement('/checks/${widget.jobId}');
        return;
      }
      if (_stopped.contains(status)) return;
      if (!_tracking) {
        _tracking = true;
        ref.read(checkCompletionMonitorProvider.notifier).track(widget.jobId);
      }
    } catch (_) {
      if (!mounted || generation != _readGeneration) return;
      setState(() => _disconnected = true);
    }
    _pollTimer = Timer(_pollInterval, () => unawaited(_read()));
  }

  Future<void> _answer(PolicyAnalysisResult question) async {
    if (_submitting) return;
    final answers = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AppDesignSurface(
        child: ClarificationDialog(
          clarificationData: {'questions': question.questions},
          contextLabel: question.displayName,
          onSubmit: (answers) => Navigator.of(context).pop(answers),
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (!mounted || answers == null || _submitting || _canLeave || _exitRequest != null) return;
    _pollTimer?.cancel();
    _readGeneration++;
    setState(() {
      _submitting = true;
      _answerFailed = false;
    });
    try {
      await ref.read(newCheckRepositoryProvider).submitAnswers(widget.jobId, question.policyId, answers);
      if (mounted && !_canLeave) {
        setState(() {
          _question = null;
          _status = 'reanalyzing';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _answerFailed = true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        unawaited(_read());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final stopped = _stopped.contains(status);
    final awaitingInput = status == 'waiting_for_user';
    final question = _question;
    final title = switch (status) {
      _ when _cancelling => 'Stopping the analysis…',
      'cancelling' => 'Stopping the analysis…',
      'waiting_for_user' => 'We need a little more information',
      'failed' => "Couldn't finish this check",
      'cancelled' => 'This check was cancelled',
      'expired' => 'This check expired',
      'created' => 'This check hasn’t started',
      'extracting_policy_metadata' || 'analyzing' || 'reanalyzing' || 'completed' => 'Checking your policies…',
      _ => 'Reading your documents…',
    };

    return FlowShell(
      onClose: _leave,
      bottomAction: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(DsSize.controlXl),
          side: BorderSide(color: context.colors.borderSubtle),
          foregroundColor: context.colors.textPrimary,
          textStyle: AppTextStyles.subheadStrong,
        ),
        onPressed: _cancelling ? null : () => _leave(goHome: true),
        child: const Text('Go to Home'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final c = context.colors;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.screenPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s16,
                children: [
                  if (!stopped) Center(child: _ProcessingArtwork(active: !awaitingInput)),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline.copyWith(color: c.textPrimary),
                    ),
                  ),
                  if (!stopped && !awaitingInput && !_disconnected && !_cancelling)
                    Center(
                      child: SizedBox(
                        width: 120,
                        child: ExcludeSemantics(
                          child: LinearProgressIndicator(
                            value: DsMotion.reduced(context) ? 0.45 : null,
                            minHeight: 4,
                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                            color: c.buttonPrimary,
                            backgroundColor: c.borderSubtle,
                          ),
                        ),
                      ),
                    ),
                  if (_disconnected)
                    AppInlineBanner(
                      kind: AppInlineBannerKind.offline,
                      message: "Couldn't refresh. Your check can keep running.",
                      onRetry: () => unawaited(_read()),
                    ),
                  if (_answerFailed)
                    const AppInlineBanner(
                      kind: AppInlineBannerKind.error,
                      message: "Couldn't save your answer. Try again.",
                    ),
                  if (_cancelFailed)
                    AppInlineBanner(
                      kind: AppInlineBannerKind.error,
                      message: "Couldn't confirm the analysis stopped. Try again.",
                      onRetry: () => unawaited(_confirmExit()),
                    ),
                  if (stopped)
                    AppButton(label: 'Start a new check', onPressed: () => context.pushReplacement('/check/new'))
                  else if (!_cancelling && awaitingInput)
                    if (question != null)
                      AppButton(label: 'Answer question', busy: _submitting, onPressed: () => _answer(question))
                    else
                      AppInlineBanner(
                        kind: AppInlineBannerKind.info,
                        message: 'No question is available yet.',
                        onRetry: () => unawaited(_read()),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProcessingArtwork extends StatefulWidget {
  const _ProcessingArtwork({required this.active});

  final bool active;

  @override
  State<_ProcessingArtwork> createState() => _ProcessingArtworkState();
}

class _ProcessingArtworkState extends State<_ProcessingArtwork> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: DsMotion.slow * 4);

  void _updateMotion() {
    if (!widget.active || DsMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(_ProcessingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _updateMotion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.drive(CurveTween(curve: DsMotion.slowCurve));
    return SizedBox(
      width: 180,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            right: 0,
            top: 0,
            width: 112,
            height: 140,
            child: FittedBox(child: AppIllustration(AppIllustrationKind.policy)),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: 112,
            height: 140,
            child: SlideTransition(
              position: progress.drive(Tween(begin: Offset.zero, end: const Offset(.28, -.12))),
              child: const FittedBox(child: AppIllustration(AppIllustrationKind.prescription)),
            ),
          ),
        ],
      ),
    );
  }
}
