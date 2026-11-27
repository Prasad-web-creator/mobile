import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/checks/data/check_jobs.dart';
import 'package:claimsupport/features/checks/presentation/check_background_notifications.dart';
import 'package:claimsupport/features/checks/presentation/check_notifications.dart';

final checkNotificationsProvider = Provider((ref) {
  final notifications = CheckNotifications();
  ref.onDispose(notifications.dispose);
  return notifications;
});

final checkCompletionMonitorProvider = NotifierProvider.autoDispose<CheckCompletionMonitor, int>(
  CheckCompletionMonitor.new,
);

/// Keeps tracking server-side checks after their processing screen is closed.
class CheckCompletionMonitor extends Notifier<int> {
  static const _interval = Duration(seconds: 6);
  final _pending = <String>{};
  final _viewing = <String>{};
  final _lastStatus = <String, String>{};
  String? _accountId;
  Timer? _timer;
  bool _polling = false;
  bool _foreground = true;

  @override
  int build() {
    final account = authProvider.select((auth) => auth.value?.id);
    _restore(ref.read(account));
    ref.listen(account, (_, next) => _restore(next));
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  void _restore(String? account) {
    if (_accountId == account) return;
    if (_accountId != null) {
      _pending.clear();
      _viewing.clear();
      _lastStatus.clear();
    }
    _accountId = account;
    if (account != null && account.isNotEmpty) {
      _pending.addAll(SharedPrefs.maybeInstance?.getStringList(pendingChecksKey(account)) ?? const []);
      for (final jobId in _pending) {
        unawaited(scheduleCheckCompletion(account, jobId));
      }
    }
    _schedule();
  }

  Future<void> _persist({String? finishedJob}) async {
    final prefs = SharedPrefs.maybeInstance;
    final account = _accountId;
    if (prefs == null || account == null || account.isEmpty) return;
    await prefs.setStringList(pendingChecksKey(account), _pending.toList());
    if (finishedJob != null) await prefs.remove(backgroundAlertKey(finishedJob));
  }

  void track(String jobId) {
    if (jobId.isEmpty || !_pending.add(jobId)) return;
    if (_viewing.contains(jobId)) unawaited(ref.read(checkNotificationsProvider).requestPermission());
    final account = _accountId;
    unawaited(
      _persist().then((_) async {
        if (account != null && account.isNotEmpty) await scheduleCheckCompletion(account, jobId);
      }),
    );
    _refreshChecks();
    _schedule();
  }

  void setProcessingView(String jobId, bool visible) {
    if (!ref.mounted) return;
    if (visible) {
      _viewing.add(jobId);
      if (_pending.contains(jobId)) unawaited(ref.read(checkNotificationsProvider).requestPermission());
    } else {
      _viewing.remove(jobId);
      if (_pending.contains(jobId)) {
        unawaited(ref.read(checkNotificationsProvider).requestPermission());
        checkNow();
      }
    }
  }

  void acknowledge(String jobId) {
    _viewing.remove(jobId);
    _lastStatus.remove(jobId);
    _pending.remove(jobId);
    unawaited(_persist(finishedJob: jobId));
    unawaited(ref.read(checkNotificationsProvider).dismiss(jobId));
    _refreshChecks(terminal: true);
    _schedule();
  }

  void _refreshChecks({bool terminal = false}) {
    ref.invalidate(checkJobsProvider);
    if (terminal) {
      ref.read(analysisReportProvider.notifier).refreshInBackground();
    }
    state++;
  }

  void _schedule() {
    _timer?.cancel();
    if (_pending.isEmpty) return;
    _timer = Timer.periodic(_interval, (_) => checkNow());
  }

  void checkNow() {
    if (!_polling && _pending.isNotEmpty) unawaited(_poll());
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    checkNow();
  }

  Future<void> _poll() async {
    _polling = true;
    final account = _accountId;
    final repository = ref.read(checkJobsRepositoryProvider);
    final notifications = ref.read(checkNotificationsProvider);
    try {
      for (final id in _pending.toList()) {
        if (_foreground && _viewing.contains(id)) continue;
        CheckJob job;
        try {
          job = await repository.find(id);
        } on DioException catch (error) {
          if (error.response?.statusCode == 404 && ref.mounted && account == _accountId) {
            _lastStatus.remove(id);
            _pending.remove(id);
            _refreshChecks(terminal: true);
            await _persist(finishedJob: id);
          }
          continue;
        } catch (_) {
          continue;
        }
        if (!ref.mounted || account != _accountId) return;
        if (!_pending.contains(id) || (_foreground && _viewing.contains(id))) continue;
        final previousStatus = _lastStatus[id];
        if (previousStatus != job.status) {
          _lastStatus[id] = job.status;
          _refreshChecks(terminal: job.isTerminal);
          if (job.hasResult) {
            final prefs = SharedPrefs.maybeInstance;
            await prefs?.reload();
            if (prefs?.getBool(backgroundAlertKey(id)) != true) {
              final treatment = await repository.treatmentFor(job);
              if (!ref.mounted || account != _accountId) return;
              if (!_pending.contains(id)) continue;
              if (_foreground && _viewing.contains(id)) {
                _lastStatus.remove(id);
                continue;
              }
              await notifications.show(job, treatment: treatment);
            }
          } else if (job.needsInput) {
            await notifications.show(job);
          }
        }
        if (!ref.mounted || account != _accountId) return;
        if (job.isTerminal) {
          _pending.remove(id);
          _lastStatus.remove(id);
          await _persist(finishedJob: id);
        }
      }
    } finally {
      _polling = false;
      if (ref.mounted && _pending.isEmpty) _timer?.cancel();
    }
  }
}

class CheckCompletionBridge extends ConsumerStatefulWidget {
  const CheckCompletionBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CheckCompletionBridge> createState() => _CheckCompletionBridgeState();
}

class _CheckCompletionBridgeState extends ConsumerState<CheckCompletionBridge> with WidgetsBindingObserver {
  late final CheckNotifications _notifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifications = ref.read(checkNotificationsProvider)..onOpen = _openJob;
    unawaited(_notifications.initialize());
  }

  Future<void> _openJob(String id) async {
    try {
      final job = await ref.read(checkJobsRepositoryProvider).find(id);
      if (!mounted) return;
      final path = job.isRunning || job.needsInput ? job.processingPath : job.resultPath;
      context.push(path);
      unawaited(_notifications.dismiss(id));
    } catch (_) {
      // The device may be offline or signed in to a different account.
      // The authenticated Home route remains available.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      ref.read(checkCompletionMonitorProvider.notifier).setForeground(state == AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifications.onOpen = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(checkCompletionMonitorProvider.notifier);
    return widget.child;
  }
}
