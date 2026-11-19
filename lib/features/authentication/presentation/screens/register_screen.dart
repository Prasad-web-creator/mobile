import 'dart:async';

import 'package:flutter/foundation.dart';
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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  static const OtpChannel _channel = OtpChannel.email;
  OtpSendResult? _sent;
  bool _loading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool get _otpSent => _sent != null;
  String get _email => _emailController.text.trim().toLowerCase();
  String get _phone => _phoneController.text.trim();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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

  Future<void> _sendOtp() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter your full name.', tone: AppTone.warning);
      return;
    }

    if (_email.isEmpty) {
      _showMessage('Please enter your email address.', tone: AppTone.warning);
      return;
    }

    if (!emailPattern.hasMatch(_email)) {
      _showMessage('Please enter a valid email address.', tone: AppTone.warning);
      return;
    }

    if (_phone.isNotEmpty) {
      final phoneRegex = RegExp(r'^[6-9][0-9]{9}$');
      if (!phoneRegex.hasMatch(_phone)) {
        _showMessage('Please enter a valid 10-digit mobile number.', tone: AppTone.warning);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final response = await ApiClient().dio.post(
        '/auth/send-otp',
        data: {
          'channel': _channel.apiValue,
          'purpose': 'register',
          'email': _email,
          if (_phone.isNotEmpty) 'phone': _phone,
        },
      );
      if (!mounted) return;
      final sent = OtpSendResult.fromResponse(response, fallbackDestination: _email);
      setState(() {
        _sent = sent;
        _otpController.clear();
      });
      _startResendTimer(sent.resendAfterSeconds);

      if (!kReleaseMode) {
        _showMessage('Test OTP is 1234', tone: AppTone.info);
      } else {
        _showMessage(sent.message, tone: AppTone.success);
      }
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
        '/auth/register',
        data: {
          'name': _nameController.text.trim(),
          'email': _email,
          'phone': _phone.isNotEmpty ? _phone : '9999999999',
          'channel': _channel.apiValue,
          'otp': otpText,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
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
      _showMessage(otpErrorFrom(e, 'Registration failed'), tone: AppTone.danger);
    } catch (e) {
      _showMessage(e.toString(), tone: AppTone.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthFieldLabel(label),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            autofillHints: autofillHints,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, size: 20),
            ),
          ),
        ],
      ),
    );
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
                    title: _otpSent ? 'Verify your account' : 'Create account',
                    subtitle: _otpSent
                        ? 'Enter the verification code sent to your email.'
                        : 'Join Policy Pal to check your insurance coverage before making a claim.',
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (!_otpSent) ...[
                    _buildTextField(
                      context,
                      label: 'Full name',
                      hint: 'Alex Morgan',
                      controller: _nameController,
                      icon: Icons.person_outline_rounded,
                      autofillHints: const [AutofillHints.name],
                      textCapitalization: TextCapitalization.words,
                    ),
                    _buildTextField(
                      context,
                      label: 'Email address',
                      hint: 'alex@example.com',
                      controller: _emailController,
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    _buildTextField(
                      context,
                      label: 'Mobile number (optional)',
                      hint: '9876543210',
                      controller: _phoneController,
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.info_outline_rounded, size: 15, color: p.textTertiary),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'A verification code will be sent to your email address.',
                            style: context.text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ] else ...[
                    OtpStatusText(sent: _sent!, channel: _channel),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTextField(
                      context,
                      label: 'One-time password',
                      hint: !kReleaseMode ? '1234' : 'Enter 4-digit OTP',
                      controller: _otpController,
                      icon: Icons.lock_outline_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_sent?.otpLength ?? 4),
                      ],
                    ),
                    if (!kReleaseMode) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: () {
                            setState(() {
                              _otpController.text = '1234';
                            });
                          },
                          icon: const Icon(Icons.flash_on_rounded, size: 16),
                          label: const Text('Auto-fill Test OTP (1234)'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],

                  PrimaryButton(
                    label: _otpSent ? 'Verify OTP & Register' : 'Send Email OTP',
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
                        child: const Text('Change Details'),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  AuthFooterLink(
                    text: 'Already have an account?',
                    linkLabel: 'Sign In',
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
