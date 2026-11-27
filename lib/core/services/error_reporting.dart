import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

const _frameworkFailure = 'Flutter framework failure';
const _asyncFailure = 'Flutter asynchronous failure';
const _allowedMessages = {_frameworkFailure, _asyncFailure};

Future<void> configureErrorReporting() async {
  const dsn = String.fromEnvironment('SENTRY_DSN');
  if (dsn.isEmpty) return;
  const configuredSampleRate = String.fromEnvironment('SENTRY_ERROR_SAMPLE_RATE', defaultValue: '1');
  const environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );
  await Sentry.init((options) {
    options.dsn = dsn;
    options.environment = environment;
    options.sampleRate = (double.tryParse(configuredSampleRate) ?? 1).clamp(0, 1).toDouble();
    options.sendDefaultPii = false;
    options.beforeSend = (event, _) {
      final message = event.message?.formatted;
      if (message == null || !_allowedMessages.contains(message)) return null;
      return SentryEvent(
        eventId: event.eventId,
        timestamp: event.timestamp,
        environment: environment,
        platform: 'dart',
        level: SentryLevel.error,
        message: SentryMessage(message),
      );
    };
  });
  FlutterError.onError = (details) {
    if (!kReleaseMode) FlutterError.presentError(details);
    unawaited(Sentry.captureMessage(_frameworkFailure, level: SentryLevel.error));
  };
  PlatformDispatcher.instance.onError = (_, _) {
    unawaited(Sentry.captureMessage(_asyncFailure, level: SentryLevel.error));
    return true;
  };
}
