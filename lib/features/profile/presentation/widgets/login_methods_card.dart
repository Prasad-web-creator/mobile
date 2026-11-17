import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/otp_method_selector.dart';

/// Shows the user's email and phone with their verification status. A verified contact
/// can be used to log in; an unverified one gets a "Verify" button (OTP sent to it).
class LoginMethodsCard extends ConsumerWidget {
  final User user;

  const LoginMethodsCard({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.cardTheme.color ?? theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Login methods', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            _row(context, ref, OtpChannel.email, user.email, user.emailVerified),
            if (user.phone != null && user.phone!.isNotEmpty)
              _row(context, ref, OtpChannel.sms, user.phone!, user.phoneVerified),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, OtpChannel channel, String value, bool verified) {
    return ListTile(
      leading: Icon(channel.icon),
      title: Text(value, overflow: TextOverflow.ellipsis),
      subtitle: Text(verified ? '${channel.label} login enabled' : 'Verify to enable ${channel.label} login'),
      trailing: verified
          ? const Chip(
              avatar: Icon(Icons.verified, color: Colors.green, size: 18),
              label: Text('Verified'),
              visualDensity: VisualDensity.compact,
            )
          : FilledButton.tonal(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _VerifyContactDialog(channel: channel, value: value),
              ).then((_) => ref.invalidate(authProvider)),
              child: const Text('Verify'),
            ),
    );
  }
}

class _VerifyContactDialog extends StatefulWidget {
  final OtpChannel channel;
  final String value;

  const _VerifyContactDialog({required this.channel, required this.value});

  @override
  State<_VerifyContactDialog> createState() => _VerifyContactDialogState();
}

class _VerifyContactDialogState extends State<_VerifyContactDialog> {
  final _otpController = TextEditingController();
  OtpSendResult? _sent;
  String? _error;
  bool _loading = false;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendSeconds = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient().dio.post('/auth/me/verify/send-otp', data: {
        'channel': widget.channel.apiValue,
      });
      if (!mounted) return;
      final sent = OtpSendResult.fromResponse(response, fallbackDestination: widget.value);
      setState(() {
        _sent = sent;
        _otpController.clear();
      });
      _startTimer(sent.resendAfterSeconds);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = otpErrorFrom(e, 'Could not send OTP. Please try again.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_otpController.text.isEmpty) {
      setState(() => _error = 'Please enter the OTP.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient().dio.post('/auth/me/verify', data: {
        'channel': widget.channel.apiValue,
        'otp': _otpController.text,
      });
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Verified. You can now log in with ${widget.channel.label}.'),
      ));
    } on DioException catch (e) {
      if (mounted) setState(() => _error = otpErrorFrom(e, 'Verification failed. Please try again.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sent;
    return AlertDialog(
      title: Text('Verify ${widget.channel == OtpChannel.email ? 'email' : 'mobile number'}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sent == null)
            Text('Sending a code to ${widget.value}...')
          else
            OtpStatusText(sent: sent, channel: widget.channel),
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            enabled: sent != null && !_loading,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(sent?.otpLength ?? 8),
            ],
            decoration: const InputDecoration(hintText: 'OTP', border: OutlineInputBorder()),
            onSubmitted: (_) => _verify(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _resendSeconds > 0
                ? Text('Resend OTP in ${_resendSeconds}s', style: const TextStyle(color: Colors.grey))
                : TextButton(onPressed: _loading ? null : _send, child: const Text('Resend OTP')),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading || sent == null ? null : _verify,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify'),
        ),
      ],
    );
  }
}
