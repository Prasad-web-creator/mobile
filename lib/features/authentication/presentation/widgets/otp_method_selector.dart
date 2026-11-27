import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

/// How the OTP is delivered. ClaimSupport uses Email OTP exclusively.
enum OtpChannel {
  email('email', 'Email OTP', Icons.email_outlined);

  const OtpChannel(this.apiValue, this.label, this.icon);
  final String apiValue;
  final String label;
  final IconData icon;
}

/// Details returned by `/auth/send-otp` and `/auth/me/verify/send-otp`.
class OtpSendResult {
  final String destination;
  final int otpLength;
  final int resendAfterSeconds;

  /// Whether the delivery request was accepted.
  final bool delivered;

  /// Message from the server, e.g. "OTP sent to su****@gmail.com".
  final String message;

  const OtpSendResult({
    required this.destination,
    required this.otpLength,
    required this.resendAfterSeconds,
    required this.delivered,
    required this.message,
  });

  /// One-line status shown above the OTP field.
  String statusText([OtpChannel channel = OtpChannel.email]) {
    return message;
  }

  factory OtpSendResult.fromResponse(Response response, {required String fallbackDestination}) {
    final data = response.data is Map ? response.data as Map : const {};
    final destination = (data['destination'] as String?) ?? fallbackDestination;
    return OtpSendResult(
      destination: destination,
      otpLength: (data['otpLength'] as num?)?.toInt() ?? 6,
      resendAfterSeconds: (data['resendAfterSeconds'] as num?)?.toInt() ?? 60,
      delivered: data['delivered'] != false,
      message: (data['message'] as String?) ?? 'OTP sent to $destination',
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
        message: sent.statusText(channel),
        padding: const EdgeInsets.all(AppSpacing.sm),
      );
    }
    return InfoBanner(tone: AppTone.warning, message: sent.message, padding: const EdgeInsets.all(AppSpacing.sm));
  }
}

/// Error text from a backend failure (FastAPI `detail`, or `message`).
String otpErrorFrom(DioException e, String fallback) {
  final data = e.response?.data;
  if (data is Map) {
    final detail = data['detail'] ?? data['message'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail != null) return 'Please check the details and try again.';
  }
  if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
    return 'No connection. Please check your internet and try again.';
  }
  return fallback;
}

String authVerificationError(DioException error) {
  final body = error.response?.data;
  final detail = body is Map ? body['detail'] ?? body['message'] : null;
  if (detail is String && detail.toLowerCase().contains('invalid or expired otp')) {
    return "That code isn't right. Check it, or get a new one.";
  }
  return otpErrorFrom(error, 'Could not verify the code. Try again.');
}

final RegExp emailPattern = RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$');
