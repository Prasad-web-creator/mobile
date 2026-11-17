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
import 'package:claimsupport/features/authentication/presentation/widgets/otp_method_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  OtpChannel _channel = OtpChannel.email;
  OtpSendResult? _sent; // non-null once an OTP has been sent
  bool _loading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool get _otpSent => _sent != null;
  bool get _isEmail => _channel == OtpChannel.email;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  /// The contact field for the selected method, as sent to the backend.
  Map<String, String> get _contact => _isEmail
      ? {'email': _emailController.text.trim().toLowerCase()}
      : {'phone': _phoneController.text.trim()};

  /// Asks the backend to send an OTP by SMS or email. Whether a real SMS / email goes out
  /// is decided on the server (OTP_PROVIDER / EMAIL_OTP_PROVIDER).
  Future<void> _sendOtp() async {
    if (_isEmail) {
      final email = _emailController.text.trim();
      if (email.isEmpty) return _showMessage('Please enter your email address.');
      if (!emailPattern.hasMatch(email)) return _showMessage('Please enter a valid email address.');
    } else {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) return _showMessage('Please enter your mobile number.');
      if (!RegExp(r'^[0-9]{1,10}$').hasMatch(phone)) {
        return _showMessage('Please enter a valid mobile number (1-10 digits).');
      }
    }

    setState(() => _loading = true);
    try {
      final response = await ApiClient().dio.post('/auth/send-otp', data: {
        'channel': _channel.apiValue,
        'purpose': 'login',
        ..._contact,
      });
      if (!mounted) return;
      final sent = OtpSendResult.fromResponse(response, fallbackDestination: _contact.values.first);
      setState(() {
        _sent = sent;
        _otpController.clear();
      });
      _startResendTimer(sent.resendAfterSeconds);
      _showMessage('OTP sent to ${sent.destination}');
    } on DioException catch (e) {
      _showMessage(otpErrorFrom(e, 'Could not send OTP. Please try again.'));
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The OTP is verified by the backend, not in the app.
  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      _showMessage('Please enter the OTP.');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await ApiClient().dio.post('/auth/login', data: {
        'channel': _channel.apiValue,
        ..._contact,
        'otp': _otpController.text,
      });

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
      _showMessage(otpErrorFrom(e, 'Login failed'));
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textColor = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSecondaryColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView( // Added scroll view for smaller screens
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Shield Icon
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.shield_outlined, color: primaryBlue, size: 48),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Icon(Icons.check, color: primaryBlue, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Welcome Back
              Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'Sign in to check your claim eligibility.',
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 32),

              if (!_otpSent) ...[
                OtpMethodSelector(
                  selected: _channel,
                  enabled: !_loading,
                  onChanged: (channel) => setState(() => _channel = channel),
                ),
                const SizedBox(height: 24),
              ] else ...[
                Text(
                  'We sent a ${_sent!.otpLength}-digit code by ${_isEmail ? 'email' : 'SMS'} to ${_sent!.destination}.',
                  style: TextStyle(fontSize: 14, color: textSecondaryColor),
                ),
                const SizedBox(height: 16),
              ],

              // Field label
                Text(
                  _otpSent ? 'Enter OTP' : (_isEmail ? 'Email Address' : 'Phone Number'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              const SizedBox(height: 8),
              
              // Text Field
              Container(
                decoration: BoxDecoration(
                  color: theme.inputDecorationTheme.fillColor ?? (isDark ? Colors.grey.shade900 : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  // A new key per field so switching method doesn't carry over keyboard/formatters.
                  key: ValueKey(_otpSent ? 'otp' : _channel.apiValue),
                  controller: _otpSent ? _otpController : (_isEmail ? _emailController : _phoneController),
                  keyboardType: _otpSent
                      ? TextInputType.number
                      : (_isEmail ? TextInputType.emailAddress : TextInputType.phone),
                  autofillHints: _otpSent
                      ? const [AutofillHints.oneTimeCode]
                      : [_isEmail ? AutofillHints.email : AutofillHints.telephoneNumber],
                  inputFormatters: _otpSent ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_sent!.otpLength),
                  ] : _isEmail ? [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ] : [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: _otpSent ? 'Enter OTP' : (_isEmail ? 'alex@example.com' : '9876543210'),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor ?? (isDark ? Colors.grey.shade900 : Colors.white),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryBlue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withAlpha(60),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryBlue.withAlpha(150),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          _otpSent ? 'Verify OTP & Login' : 'Send ${_channel.label}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              if (_otpSent) ...[
                const SizedBox(height: 16),
                Center(
                  child: _resendSeconds > 0
                      ? Text(
                          'Resend OTP in ${_resendSeconds}s',
                          style: TextStyle(color: textSecondaryColor, fontSize: 14),
                        )
                      : TextButton(
                          onPressed: _loading ? null : _sendOtp,
                          style: TextButton.styleFrom(foregroundColor: primaryBlue),
                          child: const Text(
                            'Resend OTP',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
              ],

              const SizedBox(height: 48),
              
              
              // Bottom Links
              if (!_otpSent) ...[
                const SizedBox(height: 16),
                // Register
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          context.push('/register');
                        },
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (_otpSent) ...[
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
                    style: TextButton.styleFrom(
                      foregroundColor: primaryBlue,
                    ),
                    child: const Text(
                      'Change Email / Phone or Method',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
