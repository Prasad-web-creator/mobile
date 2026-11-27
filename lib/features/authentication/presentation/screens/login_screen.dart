import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/config/app_config_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/core/network/auth_interceptor.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/otp_method_selector.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/auth_flow.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/features/authentication/data/google_identity.dart';

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
  String? _codeError;
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

  Future<void> _finishLogin(Response response) async {
    final token = response.data['token'] as String;
    final refreshToken = response.data['refreshToken'] as String?;
    await AuthStorage.saveToken(token);
    if (refreshToken != null) await AuthStorage.saveRefreshToken(refreshToken);
    AuthInterceptor.resetSessionExpiredFlag();
    if (!mounted) return;
    ref.read(homeCheckCacheProvider).clear();
    ref.read(historyCacheProvider).clear();
    ref.invalidate(policiesProvider);
    ref.invalidate(prescriptionProvider);
    ref.invalidate(analysisReportProvider);
    ref.invalidate(authProvider);
    context.go('/dashboard');
  }

  Future<void> _signInWithGoogle(String clientId) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final token = await GoogleIdentity.requestIdToken(clientId);
      if (token == null || !mounted) return;
      final response = await ApiClient().dio.post('/auth/google', data: {'idToken': token});
      await _finishLogin(response);
    } on DioException catch (error) {
      _showMessage(
        otpErrorFrom(error, 'Could not sign in with Google. Try again or use Email OTP.'),
        tone: AppTone.warning,
      );
    } catch (_) {
      _showMessage('Could not sign in with Google. Try again or use Email OTP.', tone: AppTone.warning);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (_loading || (_otpSent && _resendSeconds > 0)) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) return _showMessage('Please enter your email address.', tone: AppTone.warning);
    if (!emailPattern.hasMatch(email)) {
      return _showMessage('Please enter a valid email address.', tone: AppTone.warning);
    }

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
        _codeError = null;
        _otpController.clear();
      });
      FocusScope.of(context).unfocus();
      _startResendTimer(sent.resendAfterSeconds);

      if (!sent.delivered) _showMessage(sent.message, tone: AppTone.warning);
    } on DioException catch (e) {
      _showMessage(otpErrorFrom(e, 'Could not send OTP. Please try again.'), tone: AppTone.danger);
    } catch (e) {
      _showMessage('Could not send a verification code. Please try again.', tone: AppTone.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otpText = _otpController.text.trim();
    if (_loading || _sent == null || otpText.length != _sent!.otpLength) return;

    setState(() {
      _loading = true;
      _codeError = null;
    });
    try {
      final response = await ApiClient().dio.post(
        '/auth/login',
        data: {'channel': _channel.apiValue, ..._contact, 'otp': otpText},
      );

      if (response.statusCode == 200) await _finishLogin(response);
    } on DioException catch (e) {
      if (mounted) setState(() => _codeError = authVerificationError(e));
    } catch (e) {
      _showMessage('Could not sign in. Please try again.', tone: AppTone.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeEmail() {
    if (_loading) return;
    _resendTimer?.cancel();
    setState(() {
      _sent = null;
      _resendSeconds = 0;
      _codeError = null;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent case final sent?) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _changeEmail();
        },
        child: ValueListenableBuilder(
          valueListenable: _otpController,
          builder: (context, code, _) => AuthPage(
            title: 'Check your email',
            onBack: _changeEmail,
            actionLabel: 'Verify',
            onAction: code.text.length == sent.otpLength ? _verifyOtp : null,
            busy: _loading,
            body: [
              AuthCodeForm(
                email: _contact['email']!,
                length: sent.otpLength,
                controller: _otpController,
                secondsLeft: _resendSeconds,
                busy: _loading,
                onChangeEmail: _changeEmail,
                onResend: _sendOtp,
                onVerify: _verifyOtp,
                error: _codeError,
              ),
            ],
          ),
        ),
      );
    }
    final c = context.colors;
    final config = ref.watch(appConfigProvider).value ?? AppRuntimeConfig.defaults;
    final googleClientId = config.googleClientId;
    final showGoogle = googleClientId != null && GoogleIdentity.isSupported;
    return AuthPage(
      title: 'Log in',
      showLogo: true,
      busy: _loading,
      actionLabel: config.emailOtpEnabled ? 'Send code' : '',
      onAction: config.emailOtpEnabled ? _sendOtp : null,
      footer: config.emailOtpEnabled
          ? AuthTextAction(
              prefix: 'New to Policy Pal? ',
              label: 'Create account',
              center: true,
              onTap: _loading ? null : () => context.push('/register'),
            )
          : null,
      body: [
        Text(
          "Enter your email. We'll send you a code to log in.",
          style: AppTextStyles.subheadRegular.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: DsSpace.s20),
        if (config.emailOtpEnabled)
          AuthField(
            label: 'Email',
            controller: _emailController,
            email: true,
            enabled: !_loading,
            onSubmitted: _sendOtp,
          ),
        if (showGoogle) ...[
          const SizedBox(height: DsSpace.s16),
          AppButton(
            label: 'Continue with Google',
            style: AppButtonStyle.secondary,
            onPressed: _loading ? null : () => _signInWithGoogle(googleClientId),
          ),
        ] else if (!config.emailOtpEnabled)
          const Text('Sign-in is temporarily unavailable. Please try again later.'),
      ],
    );
  }
}
