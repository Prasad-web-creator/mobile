import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/features/checks/data/check_jobs.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';

class CheckNotifications {
  CheckNotifications({this.background = false});

  static const _preferenceKey = 'check_notifications_enabled';
  final bool background;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _enabled = ValueNotifier(SharedPrefs.maybeInstance?.getBool(_preferenceKey) ?? true);
  Future<bool>? _initialization;
  Future<bool?>? _permission;
  ValueChanged<String>? onOpen;

  ValueListenable<bool> get enabled => _enabled;

  Future<void> setEnabled(bool value) async {
    if (value == _enabled.value) return;
    final prefs = await SharedPrefs.getAsync();
    if (!await prefs.setBool(_preferenceKey, value)) {
      throw StateError('Could not save the notification preference.');
    }
    _enabled.value = value;
    if (value) _permission = null;
  }

  void dispose() => _enabled.dispose();

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> initialize() => _initialization ??= _initialize();

  Future<bool> _initialize() async {
    if (!_supported) return false;
    try {
      final initialized = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_check_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => _open(response.payload),
      );
      if (initialized != true) return false;
      if (!background) {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) _open(launch?.notificationResponse?.payload);
      }
      return true;
    } catch (error) {
      debugPrint('[CheckNotifications] Initialization failed: ${error.runtimeType}');
      return false;
    }
  }

  void _open(String? payload) {
    if (payload != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(payload)) onOpen?.call(payload);
  }

  Future<bool?> requestPermission() => _enabled.value ? (_permission ??= _requestPermission()) : Future.value(false);

  Future<bool?> _requestPermission() async {
    if (!await initialize()) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      return await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    } catch (error) {
      debugPrint('[CheckNotifications] Permission request failed: ${error.runtimeType}');
      return false;
    }
  }

  static String completionMessage(CheckJob job, String treatment) {
    final diagnosis = CheckSummary.cleanTreatment(treatment);
    final subject = diagnosis == 'Prescription' ? 'your prescription' : diagnosis;
    final count = job.policyCount;
    final policies = count > 0 ? ' across $count ${count == 1 ? 'policy' : 'policies'}' : '';
    final status = job.status == 'completed' ? 'is complete' : 'is ready to review';
    return 'Your Policy Pal analysis for $subject$policies $status. Tap to view.';
  }

  Future<bool> show(CheckJob job, {String treatment = ''}) async {
    if (!_enabled.value || !await initialize() || await _permission == false || !_enabled.value) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (await android?.areNotificationsEnabled() == false) return false;
      final body = job.needsInput ? 'Open Policy Pal to continue.' : completionMessage(job, treatment);
      await _plugin.show(
        id: _notificationId(job.id),
        title: job.needsInput ? 'Your check needs input' : 'Your check is ready',
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'check_updates',
            'Check updates',
            visibility: NotificationVisibility.private,
            onlyAlertOnce: true,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: job.id,
      );
      return true;
    } catch (error) {
      debugPrint('[CheckNotifications] Could not post: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> dismiss(String jobId) async {
    if (!await initialize()) return;
    try {
      await _plugin.cancel(id: _notificationId(jobId));
    } catch (error) {
      debugPrint('[CheckNotifications] Could not dismiss: ${error.runtimeType}');
    }
  }

  int _notificationId(String jobId) => jobId.codeUnits.fold(0, (value, unit) => (value * 31 + unit) & 0x7fffffff);
}
