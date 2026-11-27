import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/localization/locale_provider.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/core/network/auth_interceptor.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/otp_method_selector.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/auth_flow.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/account_notice.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  static const OtpChannel _channel = OtpChannel.email;
  OtpSendResult? _sent;
  bool _loading = false;
  String? _codeError;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool get _otpSent => _sent != null;
  String get _email => _emailController.text.trim().toLowerCase();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
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

  Future<void> _sendOtp() async {
    if (_loading || (_otpSent && _resendSeconds > 0)) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(context.l10n.authEnterName, tone: AppTone.warning);
      return;
    }

    if (_email.isEmpty) {
      _showMessage(context.l10n.authEnterEmail, tone: AppTone.warning);
      return;
    }

    if (!emailPattern.hasMatch(_email)) {
      _showMessage(context.l10n.authEnterValidEmail, tone: AppTone.warning);
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await ApiClient().dio.post(
        '/auth/send-otp',
        data: {'channel': _channel.apiValue, 'purpose': 'register', 'language': context.l10n.localeName, 'email': _email},
      );
      if (!mounted) return;
      final sent = OtpSendResult.fromResponse(response, fallbackDestination: _email);
      setState(() {
        _sent = sent;
        _codeError = null;
        _otpController.clear();
      });
      FocusScope.of(context).unfocus();
      _startResendTimer(sent.resendAfterSeconds);

      if (!sent.delivered) _showMessage(sent.statusText(context.l10n), tone: AppTone.warning);
    } on DioException catch (e) {
      if (!mounted) return;
      _showMessage(otpErrorFrom(e, context.l10n.authSendOtpError, context.l10n), tone: AppTone.danger);
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.l10n.authRequestError, tone: AppTone.danger);
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
        '/auth/register',
        data: {
          'name': _nameController.text.trim(),
          'email': _email,
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
        if (!mounted) return;
        final preferredLanguage = response.data['user']?['preferredLanguage'] as String?;
        await ref.read(localeProvider.notifier).restoreFromProfile(preferredLanguage);
        if (!mounted) return;
        ref.read(homeCheckCacheProvider).clear();
        ref.read(historyCacheProvider).clear();
        ref.invalidate(policiesProvider);
        ref.invalidate(prescriptionProvider);
        ref.invalidate(analysisReportProvider);
        ref.invalidate(authProvider);
        if (mounted) context.go('/dashboard');
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _codeError = authVerificationError(e, context.l10n));
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.l10n.authRequestError, tone: AppTone.danger);
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
            title: context.l10n.authCheckEmail,
            onBack: _changeEmail,
            actionLabel: context.l10n.authVerify,
            onAction: code.text.length == sent.otpLength ? _verifyOtp : null,
            busy: _loading,
            body: [
              AuthCodeForm(
                email: _email,
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
    void login() => context.canPop() ? context.pop() : context.go('/login');
    return AuthPage(
      title: context.l10n.authCreateAccount,
      onBack: login,
      actionLabel: context.l10n.authSendCode,
      onAction: _sendOtp,
      busy: _loading,
      footer: AuthTextAction(
        prefix: context.l10n.authExistingAccount,
        label: context.l10n.authLogin,
        center: true,
        onTap: _loading ? null : login,
      ),
      body: [
        Text(
          context.l10n.authRegisterDescription,
          style: AppTextStyles.subheadRegular.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: DsSpace.s20),
        AuthField(label: context.l10n.authFullName, controller: _nameController, enabled: !_loading),
        const SizedBox(height: DsSpace.s16),
        AuthField(
          label: context.l10n.authEmail,
          controller: _emailController,
          email: true,
          enabled: !_loading,
          onSubmitted: _sendOtp,
        ),
        const SizedBox(height: DsSpace.s16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              context.l10n.authLegalPrefix,
              style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary),
            ),
            _noticeLink(context.l10n.authTermsShort, AccountNotice.terms),
            Text(
              context.l10n.authLegalAnd,
              style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary),
            ),
            _noticeLink(context.l10n.authPrivacyShort, AccountNotice.privacy),
          ],
        ),
      ],
    );
  }

  Widget _noticeLink(String label, AccountNotice notice) => InkWell(
    onTap: () => notice.show(context),
    child: Text(label, style: AppTextStyles.captionStrong.copyWith(color: context.colors.textLink)),
  );
}
