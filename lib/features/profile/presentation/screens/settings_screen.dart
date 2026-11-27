import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/config/app_config_provider.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/authentication/data/google_identity.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/otp_method_selector.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSaving = false;
  bool _linkingGoogle = false;

  Future<void> _linkGoogle(String clientId) async {
    setState(() => _linkingGoogle = true);
    try {
      final token = await GoogleIdentity.requestIdToken(clientId);
      if (token == null || !mounted) return;
      await ApiClient().dio.post('/auth/me/google', data: {'idToken': token});
      if (!mounted) return;
      ref.invalidate(authProvider);
      showAppSnackBar(context, 'Google sign-in linked.', tone: AppTone.success);
    } on DioException catch (error) {
      if (mounted) {
        showAppSnackBar(context, otpErrorFrom(error, 'Could not link Google sign-in.'), tone: AppTone.warning);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not link Google sign-in.', tone: AppTone.warning);
    } finally {
      if (mounted) setState(() => _linkingGoogle = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).value;
      if (user != null) {
        _nameController.text = user.name;
        _emailController.text = user.email;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _promptEmailOtpVerification({required String name, required String newEmail}) async {
    try {
      final response = await ApiClient().dio.post('/auth/me/change-email/send-otp', data: {'newEmail': newEmail});
      final masked = response.data['destination']?.toString() ?? newEmail;
      final otpLength = OtpSendResult.fromResponse(response, fallbackDestination: masked).otpLength;

      if (!mounted) return;

      final otpController = TextEditingController();
      String? errorMessage;
      bool isSubmitting = false;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              final p = ctx.palette;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + AppSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Verify New Email Address', style: ctx.text.titleLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'We sent a verification code to $masked. Please enter it below to confirm your new email.',
                      style: ctx.text.bodyMedium?.copyWith(color: p.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: otpLength,
                      textAlign: TextAlign.center,
                      style: ctx.text.headlineSmall?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        filled: true,
                        fillColor: p.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.mdAll,
                          borderSide: BorderSide(color: p.border),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        errorMessage!,
                        style: ctx.text.bodySmall?.copyWith(color: p.danger.fg),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: isSubmitting ? 'Verifying...' : 'Verify & Save',
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final otp = otpController.text.trim();
                              if (otp.isEmpty) {
                                setModalState(() => errorMessage = 'Please enter the verification code.');
                                return;
                              }
                              setModalState(() {
                                isSubmitting = true;
                                errorMessage = null;
                              });
                              try {
                                await ApiClient().dio.post(
                                  '/auth/me/change-email/verify',
                                  data: {'newEmail': newEmail, 'otp': otp, 'name': name},
                                );
                                ref.invalidate(authProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  showAppSnackBar(context, 'Email updated successfully!', tone: AppTone.success);
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  errorMessage = friendlyErrorMessage(e);
                                });
                              }
                            },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Could not send verification code: ${friendlyErrorMessage(e)}', tone: AppTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final clientId = ref.watch(appConfigProvider).value?.googleClientId;
    final currentUser = ref.watch(authProvider).value;
    final canLinkGoogle = currentUser?.emailVerified == true && clientId != null && GoogleIdentity.isSupported;

    return PushedShell(
      title: 'Edit Profile',
      onBack: () => context.canPop() ? context.pop() : context.go('/dashboard'),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xxl),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'Personal Information',
                  subtitle: 'Used on your account and analysis reports.',
                ),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Full Name', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Enter your full name',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                          filled: true,
                          fillColor: p.surfaceMuted,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.mdAll,
                            borderSide: BorderSide(color: p.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.mdAll,
                            borderSide: BorderSide(color: p.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.mdAll,
                            borderSide: BorderSide(color: p.primary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Email Address', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter your email address',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          filled: true,
                          fillColor: p.surfaceMuted,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.mdAll,
                            borderSide: BorderSide(color: p.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.mdAll,
                            borderSide: BorderSide(color: p.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.mdAll,
                            borderSide: BorderSide(color: p.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save Changes',
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final name = _nameController.text.trim();
                          final email = _emailController.text.trim();

                          if (name.isEmpty) {
                            showAppSnackBar(context, 'Name cannot be empty', tone: AppTone.warning);
                            return;
                          }

                          // Basic email validation regex
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (email.isEmpty || !emailRegex.hasMatch(email)) {
                            showAppSnackBar(context, 'Please enter a valid email address', tone: AppTone.warning);
                            return;
                          }

                          final currentUser = ref.read(authProvider).value;
                          final currentEmail = currentUser?.email.trim().toLowerCase() ?? '';
                          final targetEmail = email.toLowerCase();

                          if (targetEmail != currentEmail) {
                            // Email changed: require OTP verification
                            await _promptEmailOtpVerification(name: name, newEmail: targetEmail);
                            return;
                          }

                          // Only name changed
                          setState(() => _isSaving = true);
                          try {
                            await ref.read(authProvider.notifier).updateProfile(name, currentUser?.email ?? email);
                            if (context.mounted) {
                              showAppSnackBar(context, 'Profile updated successfully!', tone: AppTone.success);
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showAppSnackBar(
                                context,
                                'Failed to update profile: ${friendlyErrorMessage(e)}',
                                tone: AppTone.danger,
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                ),
                if (canLinkGoogle || currentUser?.googleLinked == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (currentUser?.googleLinked == true)
                    const Text('Google sign-in is linked.')
                  else
                    SecondaryButton(
                      label: _linkingGoogle ? 'Linking Google…' : 'Link Google sign-in',
                      onPressed: _linkingGoogle ? null : () => _linkGoogle(clientId!),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
