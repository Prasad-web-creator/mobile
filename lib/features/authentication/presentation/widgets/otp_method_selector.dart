import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  /// False when the server did not actually send an email (static/test mode).
  final bool delivered;

  /// Message to show the user, e.g. "OTP sent to ..." or "Development Mode: Use test OTP 1234."
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
    if (!kReleaseMode && !delivered) {
      return 'Development Mode: Use test OTP 1234 to verify.';
    }
    return delivered ? 'We sent a $otpLength-digit code by email to $destination.' : message;
  }

  factory OtpSendResult.fromResponse(Response response, {required String fallbackDestination}) {
    final data = response.data is Map ? response.data as Map : const {};
    final destination = (data['destination'] as String?) ?? fallbackDestination;
    return OtpSendResult(
      destination: destination,
      otpLength: (data['otpLength'] as num?)?.toInt() ?? 4,
      resendAfterSeconds: (data['resendAfterSeconds'] as num?)?.toInt() ?? 30,
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
    if (!kReleaseMode && !sent.delivered) {
      return const InfoBanner(
        tone: AppTone.info,
        icon: Icons.developer_mode_rounded,
        title: 'Development Testing',
        message: 'Fixed test OTP is: 1234',
        padding: EdgeInsets.all(AppSpacing.sm),
      );
    }
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

final RegExp emailPattern = RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$');

/// "Continue with Email OTP" / "Continue with SMS OTP" choice, shown as a segmented control.
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
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          for (final channel in OtpChannel.values) ...[
            if (channel != OtpChannel.values.first) const SizedBox(width: 4),
            Expanded(child: _option(context, channel)),
          ],
        ],
      ),
    );
  }

  Widget _option(BuildContext context, OtpChannel channel) {
    final p = context.palette;
    final isSelected = channel == selected;
    final foreground = isSelected ? p.primary : p.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$prefix ${channel.label}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.smAll,
          onTap: enabled ? () => onChanged(channel) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? p.surface : Colors.transparent,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: isSelected ? p.primary.withAlpha(90) : Colors.transparent),
              boxShadow: isSelected ? p.softShadow : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(channel.icon, color: foreground, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    channel.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      fontSize: 14,
                      color: foreground,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand mark + title + subtitle used at the top of the sign-in and registration screens.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: p.primary, borderRadius: AppRadius.mdAll),
              child: Icon(Icons.health_and_safety_rounded, color: p.onPrimary, size: 26),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Policy Pal', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(title, style: context.text.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: context.text.bodyLarge?.copyWith(color: p.textSecondary)),
      ],
    );
  }
}

/// Label shown above an auth form field.
class AuthFieldLabel extends StatelessWidget {
  final String text;

  const AuthFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: context.text.titleSmall),
    );
  }
}

/// "Text + link" row at the bottom of the auth screens.
class AuthFooterLink extends StatelessWidget {
  final String text;
  final String linkLabel;
  final VoidCallback onTap;

  const AuthFooterLink({super.key, required this.text, required this.linkLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: context.text.bodyMedium),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(linkLabel),
        ),
      ],
    );
  }
}

/// Resend countdown / resend button shown after an OTP is sent.
class OtpResendRow extends StatelessWidget {
  final int secondsLeft;
  final bool loading;
  final VoidCallback onResend;

  const OtpResendRow({super.key, required this.secondsLeft, required this.loading, required this.onResend});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: secondsLeft > 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: p.textTertiary),
                  const SizedBox(width: 6),
                  Text('Resend OTP in ${secondsLeft}s', style: context.text.bodyMedium),
                ],
              ),
            )
          : TextButton.icon(
              onPressed: loading ? null : onResend,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Resend OTP'),
            ),
    );
  }
}
