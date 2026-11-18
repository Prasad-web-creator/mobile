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
  OtpChannel _channel = OtpChannel.email;
  OtpSendResult? _sent; // non-null once an OTP has been sent
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

  /// Asks the backend to send an OTP to the chosen contact (email or phone). Whether a
  /// real SMS / email goes out is decided on the server (OTP_PROVIDER / EMAIL_OTP_PROVIDER).
  Future<void> _sendOtp() async {
    final phoneRegex = RegExp(r'^[6-9][0-9]{9}$');

    if (_nameController.text.trim().isEmpty || _email.isEmpty || _phone.isEmpty) {
      _showMessage('Please fill all fields first.');
      return;
    }

    if (!emailPattern.hasMatch(_email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (!phoneRegex.hasMatch(_phone)) {
      _showMessage('Please enter a valid 10-digit mobile number.');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await ApiClient().dio.post('/auth/send-otp', data: {
        'channel': _channel.apiValue,
        'purpose': 'register',
        'phone': _phone,
        'email': _email,
      });
      if (!mounted) return;
      final sent = OtpSendResult.fromResponse(
        response,
        fallbackDestination: _channel == OtpChannel.email ? _email : _phone,
      );
      setState(() {
        _sent = sent;
        _otpController.clear();
      });
      _startResendTimer(sent.resendAfterSeconds);
      _showMessage(sent.message);
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
      final response = await ApiClient().dio.post('/auth/register', data: {
        'name': _nameController.text.trim(),
        'email': _email,
        'phone': _phone,
        'channel': _channel.apiValue,
        'otp': _otpController.text,
      });

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
      _showMessage(otpErrorFrom(e, 'Registration failed'));
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTextField(BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
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
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            decoration: InputDecoration(
              hintText: hint,
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
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Title
              Text(
                'Create Account',
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
                'Join Policy Pal today.',
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 48),
              
              if (!_otpSent) ...[
                _buildTextField(
                  context,
                  label: 'Full Name',
                  hint: 'Alex Morgan',
                  controller: _nameController,
                ),
                _buildTextField(
                  context,
                  label: 'Email Address',
                  hint: 'alex@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildTextField(
                  context,
                  label: 'Phone Number',
                  hint: '9876543210',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                Text(
                  'Verify with',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 8),
                OtpMethodSelector(
                  selected: _channel,
                  enabled: !_loading,
                  onChanged: (channel) => setState(() => _channel = channel),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can log in with either method later, once that contact is verified.',
                  style: TextStyle(fontSize: 13, color: textSecondaryColor),
                ),
                const SizedBox(height: 24),
              ] else ...[
                OtpStatusText(sent: _sent!, channel: _channel),
                const SizedBox(height: 16),
                _buildTextField(
                  context,
                  label: 'Enter OTP',
                  hint: 'Enter ${_sent!.otpLength}-digit OTP',
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_sent!.otpLength),
                  ],
                ),
              ],
              
              const SizedBox(height: 8),
              
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
                          _otpSent ? 'Verify OTP & Register' : 'Send ${_channel.label}',
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
                    style: TextButton.styleFrom(foregroundColor: primaryBlue),
                    child: const Text(
                      'Change Details',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 48),
              
              // Bottom Links
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: textSecondaryColor,
                        fontSize: 15,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        context.pop(); // Go back to login
                      },
                      child: Text(
                        'Sign In',
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
