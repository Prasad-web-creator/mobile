import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// How the OTP is delivered. The value is what the backend expects in `channel`.
enum OtpChannel {
  email('email', 'Email OTP', Icons.email_outlined),
  sms('sms', 'SMS OTP', Icons.sms_outlined);

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

  /// False when the server did not actually send an SMS/email (no OTP service set up).
  final bool delivered;

  /// Message to show the user, e.g. "OTP sent to ..." or "OTP could not be sent ... use test OTP 1234."
  final String message;

  const OtpSendResult({
    required this.destination,
    required this.otpLength,
    required this.resendAfterSeconds,
    required this.delivered,
    required this.message,
  });

  /// One-line status shown above the OTP field.
  String statusText(OtpChannel channel) => delivered
      ? 'We sent a $otpLength-digit code by ${channel == OtpChannel.email ? 'email' : 'SMS'} to $destination.'
      : message;

  factory OtpSendResult.fromResponse(Response response, {required String fallbackDestination}) {
    final data = response.data is Map ? response.data as Map : const {};
    final destination = (data['destination'] as String?) ?? fallbackDestination;
    return OtpSendResult(
      destination: destination,
      // Older backends did not send these; their OTP was 4 digits with a 30 s cooldown.
      otpLength: (data['otpLength'] as num?)?.toInt() ?? 4,
      resendAfterSeconds: (data['resendAfterSeconds'] as num?)?.toInt() ?? 30,
      delivered: data['delivered'] != false,
      message: (data['message'] as String?) ?? 'OTP sent to $destination',
    );
  }
}

/// Status line above the OTP field; amber warning when the OTP was not actually delivered.
class OtpStatusText extends StatelessWidget {
  final OtpSendResult sent;
  final OtpChannel channel;

  const OtpStatusText({super.key, required this.sent, required this.channel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (sent.delivered) {
      return Text(
        sent.statusText(channel),
        style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : const Color(0xFF6B7280)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x33F59E0B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sent.message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
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

final RegExp emailPattern = RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$');

/// "Continue with Email OTP" / "Continue with SMS OTP" choice.
class OtpMethodSelector extends StatelessWidget {
  final OtpChannel selected;
  final ValueChanged<OtpChannel> onChanged;
  final bool enabled;
  final String prefix;

  const OtpMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.prefix = 'Continue with',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final channel in OtpChannel.values) ...[
          if (channel != OtpChannel.values.first) const SizedBox(width: 12),
          Expanded(child: _option(context, channel)),
        ],
      ],
    );
  }

  Widget _option(BuildContext context, OtpChannel channel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryBlue = Color(0xFF2563EB);
    final isSelected = channel == selected;
    final foreground = isSelected ? primaryBlue : (isDark ? Colors.grey.shade300 : const Color(0xFF374151));

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$prefix ${channel.label}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => onChanged(channel) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryBlue.withAlpha(isDark ? 50 : 20)
                : (theme.inputDecorationTheme.fillColor ?? (isDark ? Colors.grey.shade900 : Colors.white)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryBlue : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(channel.icon, color: foreground),
              const SizedBox(height: 6),
              Text(
                prefix,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : const Color(0xFF6B7280)),
              ),
              Text(
                channel.label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
