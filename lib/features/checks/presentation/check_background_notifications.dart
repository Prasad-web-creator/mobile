import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'package:claimsupport/core/config/env_config.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/features/checks/data/check_jobs.dart';
import 'package:claimsupport/features/checks/presentation/check_notifications.dart';

const _task = 'policy_check_completion';

String pendingChecksKey(String account) => 'pending_policy_checks_$account';
String backgroundAlertKey(String jobId) => 'policy_check_alerted_$jobId';

Future<void> scheduleCheckCompletion(String account, String jobId) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(jobId)) return;
  try {
    final scheduler = Workmanager();
    await scheduler.initialize(checkCompletionDispatcher);
    await scheduler.registerOneOffTask(
      '$_task:$jobId',
      _task,
      inputData: {'account': account, 'jobId': jobId},
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 15),
    );
  } catch (error) {
    debugPrint('[CheckCompletion] Could not schedule background check: ${error.runtimeType}');
  }
}

@pragma('vm:entry-point')
void checkCompletionDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((task, input) async {
    if (task != _task || input?['account'] is! String || input?['jobId'] is! String) return true;
    return _checkCompletion(input!['account'] as String, input['jobId'] as String);
  });
}

Future<bool> _checkCompletion(String account, String jobId) async {
  final prefs = await SharedPrefs.getAsync();
  Future<bool> isPending() async {
    await prefs.reload();
    return (prefs.getStringList(pendingChecksKey(account))?.contains(jobId) ?? false) &&
        prefs.getBool(backgroundAlertKey(jobId)) != true;
  }

  if (!await isPending()) return true;
  final token = await AuthStorage.getToken();
  if (token == null || _accountForToken(token) != account) return true;

  // Reading one job requires an access token. Refresh token rotation stays in
  // the app isolate so a scheduled check cannot race login or logout.
  final client = Dio(
    BaseOptions(
      baseUrl: EnvConfig.apiBaseUrl,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  try {
    final repository = CheckJobsRepository(client: client);
    final job = await repository.find(jobId);
    if (!job.isTerminal) return false;
    if (!job.hasResult) return true;
    final treatment = await repository.treatmentFor(job);
    if (!await isPending()) return true;
    final currentToken = await AuthStorage.getToken();
    if (currentToken == null || _accountForToken(currentToken) != account) return true;
    final notifications = CheckNotifications(background: true);
    try {
      if (await notifications.show(job, treatment: treatment)) {
        await prefs.setBool(backgroundAlertKey(jobId), true);
      }
    } finally {
      notifications.dispose();
    }
    return true;
  } on DioException catch (error) {
    return const {401, 403, 404}.contains(error.response?.statusCode);
  } finally {
    client.close();
  }
}

String? _accountForToken(String token) {
  try {
    final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))));
    final user = claims is Map ? claims['user'] : null;
    final id = user is Map ? user['id'] : null;
    return id is String ? id : null;
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  }
}
