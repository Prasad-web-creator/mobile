import 'package:claimsupport/core/localization/localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

/// How the OTP is delivered. ClaimSupport uses Email OTP exclusively.
enum OtpChannel {
  email('email', Icons.email_outlined);

  const OtpChannel(this.apiValue, this.icon);
  final String apiValue;
  final IconData icon;
}

/// Details returned by `/auth/send-otp` and `/auth/me/verify/send-otp`.
class OtpSendResult {
  final String destination;
  final int otpLength;
  final int resendAfterSeconds;

  /// Whether the delivery request was accepted.
  final bool delivered;

  const OtpSendResult({
    required this.destination,
    required this.otpLength,
    required this.resendAfterSeconds,
    required this.delivered,
  });

  /// One-line status shown above the OTP field.
  String statusText(AppLocalizations l10n) =>
      delivered ? l10n.authOtpSent(destination) : l10n.authSendOtpError;

  factory OtpSendResult.fromResponse(Response response, {required String fallbackDestination}) {
    final data = response.data is Map ? response.data as Map : const {};
    final destination = (data['destination'] as String?) ?? fallbackDestination;
    return OtpSendResult(
      destination: destination,
      otpLength: (data['otpLength'] as num?)?.toInt() ?? 6,
      resendAfterSeconds: (data['resendAfterSeconds'] as num?)?.toInt() ?? 60,
      delivered: data['delivered'] != false,
    );
  }
}

/// Status line above the OTP field.
class OtpStatusText extends StatelessWidget {
  final OtpSendResult sent;
  final OtpChannel channel;

  const OtpStatusText({super.key, required this.sent, this.channel = OtpChannel.email});

  @override
  Widget build(BuildContext context) {
    if (sent.delivered) {
      return InfoBanner(
        tone: AppTone.info,
        icon: channel.icon,
        message: sent.statusText(context.l10n),
        padding: const EdgeInsets.all(AppSpacing.sm),
      );
    }
    return InfoBanner(
      tone: AppTone.warning,
      message: sent.statusText(context.l10n),
      padding: const EdgeInsets.all(AppSpacing.sm),
    );
  }
}

/// Error text from a backend failure (FastAPI `detail`, or `message`).
String otpErrorFrom(DioException error, String fallback, AppLocalizations l10n) {
  final status = error.response?.statusCode;
  final data = error.response?.data;
  final detail = data is Map ? data['detail'] ?? data['message'] : null;
  if (status == 429) return l10n.authTooManyRequests;
  if (detail is String && detail.isNotEmpty) {
    final localized = switch (detail) {
      'This email address is already registered. Please login.' => l10n.authEmailRegistered,
      'No account found with this email address. Please register first.' => l10n.authNoAccount,
      'Email OTP service is not configured.' ||
      'Email OTP service is temporarily unavailable.' => l10n.authOtpUnavailable,
      'This email address cannot receive email. Please check it.' => l10n.authUndeliverable,
      'This Google account is already linked.' => l10n.authGoogleAlreadyLinked,
      _ => null,
    };
    return localized ?? (l10n.localeName == 'en' ? detail : fallback);
  }
  if (detail != null) return l10n.authCheckDetails;
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return l10n.authNoConnection;
  }
  return fallback;
}

String authVerificationError(DioException error, AppLocalizations l10n) {
  final body = error.response?.data;
  final detail = body is Map ? body['detail'] ?? body['message'] : null;
  if (detail is String && detail.toLowerCase().contains('invalid or expired otp')) {
    return l10n.authInvalidOtp;
  }
  return otpErrorFrom(error, l10n.authCouldNotVerify, l10n);
}

final RegExp emailPattern = RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$');
