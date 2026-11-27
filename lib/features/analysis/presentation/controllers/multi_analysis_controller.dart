import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;

import 'package:claimsupport/features/analysis/data/models/multi_analysis_session.dart';
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';
import 'package:claimsupport/features/analysis/presentation/controllers/analysis_controller.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';

class MultiAnalysisParams {
  final String prescriptionPath;
  final List<String> policyIds;

  MultiAnalysisParams({required this.prescriptionPath, required this.policyIds});
}

/// Drives a multi-policy analysis: start, per-policy clarification, per-policy retry.
///
/// `/analysis/start-multi` returns as soon as the session exists, so the screen
/// gets a real list of policies immediately. From there the notifier polls
/// `/analysis/multi/{id}`, and every update it publishes is a state the backend
/// has actually reached — the progress shown is recorded work, never a timer.
class MultiAnalysisNotifier extends Notifier<AsyncValue<MultiAnalysisSession>> {
  /// How often the session is re-read while work is in flight.
  static const Duration _pollInterval = Duration(seconds: 2);

  /// Transient network hiccups should not kill a running analysis; only a
  /// sustained run of failures is treated as a real error.
  static const int _maxConsecutivePollFailures = 5;

  CancelToken? _cancelToken;
  MultiAnalysisParams? _params;
  bool _disposed = false;
  bool _polling = false;
  String? _jobId;

  /// Policies whose answer/retry request has been sent but not yet confirmed
  /// by the server, with the "restarted" row to show meanwhile. A poll that
  /// was read just before the server received the request must not bring the
  /// already-answered question back (answering it twice made the policy fail).
  final Map<String, PolicyAnalysisResult> _inFlight = {};

  /// Publish a server snapshot, keeping in-flight policies in their restarted state.
  void _publish(MultiAnalysisSession session) {
    if (_disposed) return;
    final overrides = <String, PolicyAnalysisResult>{};
    for (final p in session.policyAnalyses) {
      final local = _inFlight[p.policyId];
      if (local != null && (p.isWaitingForUser || p.isFailed)) overrides[p.policyId] = local;
    }
    state = AsyncValue.data(session.withPolicies(overrides));
  }

  MultiAnalysisParams? get params => _params;

  @override
  AsyncValue<MultiAnalysisSession> build() {
    ref.onDispose(() {
      _disposed = true;
      _cancelToken?.cancel();
    });
    return const AsyncValue.loading();
  }

  Future<void> startAnalysis(MultiAnalysisParams params) async {
    _params = params;
    _cancelToken = CancelToken();

    state = const AsyncValue.loading();
    try {
      final repository = ref.read(analysisRepositoryProvider);
      _jobId = SharedPrefs.instance.getString(analysisDraftKey);
      final jobId = _jobId;
      final result = jobId == null ? await repository.startMultiAnalysis(
        params.prescriptionPath,
        params.policyIds,
        cancelToken: _cancelToken!,
      ) : await repository.startJob(
        jobId, params.prescriptionPath, params.policyIds, _cancelToken!,
      );
      if (jobId != null) await SharedPrefs.instance.setString(analysisResumeKey, jobId);
      if (_disposed) return;

      final session = MultiAnalysisSession.fromJson(result);
      developer.log('[MultiAnalysis] session=${session.sessionId} '
          'policies=${session.policyCount} — following progress');
      state = AsyncValue.data(session);
      unawaited(_followProgress(session.sessionId));
    } catch (e, st) {
      developer.log('[MultiAnalysis] Analysis request failed.');
      if (!_disposed) state = AsyncValue.error(e, st);
    }
  }

  /// Re-read the session until the backend has no work left in flight.
  ///
  /// Each successful read replaces the state, so the UI's step counts, stage
  /// labels and per-policy statuses are always the server's real ones.
  Future<void> _followProgress(String sessionId) async {
    if (_polling || sessionId.isEmpty) return;
    _polling = true;
    var consecutiveFailures = 0;

    try {
      while (!_disposed) {
        final current = state.asData?.value;
        if (current != null && !current.isWorking) break;

        await Future<void>.delayed(_pollInterval);
        if (_disposed) break;

        try {
          final repository = ref.read(analysisRepositoryProvider);
          final result = await _fetch(repository, sessionId);
          if (_disposed) break;

          consecutiveFailures = 0;
          _publish(MultiAnalysisSession.fromJson(result));
          final session = state.asData!.value;

          if (!session.isWorking && _inFlight.isEmpty) {
            developer.log('[MultiAnalysis] session=$sessionId settled '
                'status=${session.status} '
                '${session.completedCount}/${session.policyCount} finished');
            break;
          }
        } catch (e, st) {
          consecutiveFailures++;
          developer.log('[MultiAnalysis] Poll failed ($consecutiveFailures).');
          if (consecutiveFailures >= _maxConsecutivePollFailures) {
            if (!_disposed) state = AsyncValue.error(e, st);
            break;
          }
        }
      }
    } finally {
      _polling = false;
    }
  }

  /// Answer one policy's clarification questions. Other policies keep their results.
  ///
  /// The server only records the answers and re-analyses this policy in the
  /// background, so the request returns quickly; progress is then followed by
  /// polling like the rest of the comparison.
  Future<void> submitPolicyAnswers(String policyId, Map<String, dynamic> answers) async {
    await _restartPolicy(
      policyId,
      'reanalyzing',
      (repository, sessionId, token) =>
          _jobId == null
              ? repository.submitPolicyAnswers(sessionId, policyId, answers, cancelToken: token)
              : repository.updateJob(sessionId, 'answer', policyId, token, answers: answers),
      'answer',
    );
  }

  /// Retry a single failed policy. Successful policies are untouched.
  Future<void> retryPolicy(String policyId) async {
    await _restartPolicy(
      policyId,
      'queued',
      (repository, sessionId, token) =>
          _jobId == null
              ? repository.retryPolicy(sessionId, policyId, cancelToken: token)
              : repository.updateJob(sessionId, 'retry', policyId, token),
      'retry',
    );
  }

  Future<void> _restartPolicy(
    String policyId,
    String restartStatus,
    Future<Map<String, dynamic>> Function(AnalysisRepository repository, String sessionId, CancelToken token)
        send,
    String action,
  ) async {
    final current = state.asData?.value;
    if (current == null || _inFlight.containsKey(policyId)) return;

    final token = CancelToken();
    _cancelToken = token;
    developer.log('[MultiAnalysis] $action policy=$policyId');

    // Reflect the restart straight away; the other policies' results stay on
    // screen throughout.
    final restarted = current.withPolicyRestarted(policyId, restartStatus);
    final row = restarted.policyAnalyses.where((p) => p.policyId == policyId).firstOrNull;
    if (row != null) _inFlight[policyId] = row;
    state = AsyncValue.data(restarted);

    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await send(repository, current.sessionId, token);
      _inFlight.remove(policyId);
      _publish(MultiAnalysisSession.fromJson(result));
    } catch (e) {
      developer.log('[MultiAnalysis] $action request failed.');
      _inFlight.remove(policyId);
      // Show the server's real state for this policy rather than a guess.
      try {
        final repository = ref.read(analysisRepositoryProvider);
        _publish(MultiAnalysisSession.fromJson(
          await _fetch(repository, current.sessionId),
        ));
      } catch (_) {}
    }
    if (!_disposed) unawaited(_followProgress(current.sessionId));
  }

  /// Re-read the session, e.g. after the user returns to the screen.
  Future<void> refreshSession(String sessionId) async {
    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await _fetch(repository, sessionId);
      if (_disposed) return;
      _publish(MultiAnalysisSession.fromJson(result));
      if (state.asData?.value.isWorking ?? false) unawaited(_followProgress(sessionId));
    } catch (e, st) {
      if (!_disposed) state = AsyncValue.error(e, st);
    }
  }

  Future<void> resumeJob(String jobId) async {
    _jobId = jobId;
    await refreshSession(jobId);
  }

  Future<void> resumeSession(String sessionId) async {
    _jobId = null;
    await refreshSession(sessionId);
  }

  Future<Map<String, dynamic>> _fetch(AnalysisRepository repository, String sessionId) =>
      _jobId == null ? repository.fetchMultiAnalysis(sessionId) : repository.fetchJob(sessionId);

  Future<void> cancelAnalysis() async {
    final jobId = _jobId;
    if (jobId == null) return;
    final result = await ref.read(analysisRepositoryProvider).cancelJob(jobId);
    _publish(MultiAnalysisSession.fromJson(result));
  }
}

final multiAnalysisJobProvider =
    NotifierProvider.autoDispose<MultiAnalysisNotifier, AsyncValue<MultiAnalysisSession>>(
  MultiAnalysisNotifier.new,
);
