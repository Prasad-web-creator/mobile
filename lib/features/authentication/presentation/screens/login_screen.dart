import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/core/network/auth_interceptor.dart';
import 'package:flutter/services.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/otp_method_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  static const OtpChannel _channel = OtpChannel.email;
  OtpSendResult? _sent;
  bool _loading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool get _otpSent => _sent != null;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {AppTone tone = AppTone.neutral}) {
    if (!mounted) return;
    showAppSnackBar(context, message, tone: tone);
  }

  void _startResendTimer(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    if (seconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Map<String, String> get _contact => {'email': _emailController.text.trim().toLowerCase()};

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return _showMessage('Please enter your email address.', tone: AppTone.warning);
    if (!emailPattern.hasMatch(email)) return _showMessage('Please enter a valid email address.', tone: AppTone.warning);

    setState(() => _loading = true);
    try {
      final response = await ApiClient().dio.post(
        '/auth/send-otp',
        data: {'channel': _channel.apiValue, 'purpose': 'login', ..._contact},
      );
      if (!mounted) return;
      final sent = OtpSendResult.fromResponse(response, fallbackDestination: _contact['email']!);
      setState(() {
        _sent = sent;
        _otpController.clear();
      });
      _startResendTimer(sent.resendAfterSeconds);

      _showMessage(sent.message, tone: sent.delivered ? AppTone.success : AppTone.warning);
    } on DioException catch (e) {
      _showMessage(otpErrorFrom(e, 'Could not send OTP. Please try again.'), tone: AppTone.danger);
    } catch (e) {
      _showMessage(e.toString(), tone: AppTone.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otpText = _otpController.text.trim();
    if (otpText.isEmpty) {
      _showMessage('Please enter the OTP.', tone: AppTone.warning);
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await ApiClient().dio.post(
        '/auth/login',
        data: {'channel': _channel.apiValue, ..._contact, 'otp': otpText},
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final refreshToken = response.data['refreshToken'];
        await AuthStorage.saveToken(token);
        if (refreshToken != null) {
          await AuthStorage.saveRefreshToken(refreshToken);
        }
        AuthInterceptor.resetSessionExpiredFlag();
        ref.invalidate(authProvider);
        if (mounted) context.go('/dashboard');
      }
    } on DioException catch (e) {
      _showMessage(otpErrorFrom(e, 'Login failed'), tone: AppTone.danger);
    } catch (e) {
      _showMessage(e.toString(), tone: AppTone.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
            child: ContentWidth(
              maxWidth: 440,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(
                    title: _otpSent ? 'Verify it\'s you' : 'Welcome back',
                    subtitle: _otpSent
                        ? 'Enter the verification code sent to your email.'
                        : 'Sign in to review and analyze your insurance coverage.',
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (_otpSent) ...[
                    OtpStatusText(sent: _sent!, channel: _channel),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  AuthFieldLabel(_otpSent ? 'One-time password' : 'Email address'),
                  TextField(
                    key: ValueKey(_otpSent ? 'otp' : 'email'),
                    controller: _otpSent ? _otpController : _emailController,
                    keyboardType: _otpSent ? TextInputType.number : TextInputType.emailAddress,
                    autofillHints: _otpSent ? const [AutofillHints.oneTimeCode] : const [AutofillHints.email],
                    inputFormatters: _otpSent
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(_sent?.otpLength ?? 4),
                          ]
                        : [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                    style: _otpSent ? context.text.titleLarge?.copyWith(letterSpacing: 8) : context.text.bodyLarge,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _otpSent ? _verifyOtp() : _sendOtp(),
                    decoration: InputDecoration(
                      hintText: _otpSent
                          ? 'Enter ${_sent?.otpLength ?? 4}-digit code'
                          : 'alex@example.com',
                      hintStyle: _otpSent ? context.text.bodyLarge?.copyWith(color: p.textTertiary) : null,
                      prefixIcon: Icon(
                        _otpSent ? Icons.lock_outline_rounded : Icons.alternate_email_rounded,
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  PrimaryButton(
                    label: _otpSent ? 'Verify OTP & Login' : 'Send Email OTP',
                    loading: _loading,
                    onPressed: _otpSent ? _verifyOtp : _sendOtp,
                  ),

                  if (_otpSent) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OtpResendRow(secondsLeft: _resendSeconds, loading: _loading, onResend: _sendOtp),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          _resendTimer?.cancel();
                          setState(() {
                            _sent = null;
                            _resendSeconds = 0;
                            _otpController.clear();
                          });
                        },
                        child: const Text('Change Email Address'),
                      ),
                    ),
                  ],

                  if (!_otpSent) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(child: Divider(color: p.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: Text('New to Policy Pal?', style: context.text.bodySmall),
                        ),
                        Expanded(child: Divider(color: p.border)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(label: 'Create an account', onPressed: () => context.push('/register')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
