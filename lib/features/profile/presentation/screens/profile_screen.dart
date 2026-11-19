import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/theme/theme_provider.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/core/network/auth_interceptor.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showAccountInfo(BuildContext context, User user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final p = ctx.palette;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            MediaQuery.of(ctx).padding.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Account Information', style: ctx.text.titleLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text('Your Policy Pal identity and verified contact details', style: ctx.text.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    KeyValueRow(label: 'Full Name', value: user.name),
                    Divider(height: 1, color: p.border),
                    KeyValueRow(label: 'Email Address', value: user.email),
                    Divider(height: 1, color: p.border),
                    KeyValueRow(
                      label: 'Mobile Number',
                      value: user.phone != null && user.phone!.isNotEmpty ? user.phone! : 'Not provided',
                    ),
                    Divider(height: 1, color: p.border),
                    KeyValueRow(
                      label: 'Account Status',
                      value: user.emailVerified ? 'Active & Verified' : 'Standard Member',
                      valueColor: user.emailVerified ? p.success.fg : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            MediaQuery.of(ctx).padding.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Help & Support', style: ctx.text.titleLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text('Policy Pal assistance and claim advisory guidance', style: ctx.text.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconTile(icon: Icons.support_agent_rounded, tone: AppTone.brand, size: 38),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customer Care', style: ctx.text.titleSmall),
                              Text('support@claimsupport.com', style: ctx.text.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'Copy support email',
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: 'support@claimsupport.com'));
                            showAppSnackBar(ctx, 'Support email copied to clipboard!', tone: AppTone.success);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 42)),
                      onPressed: () async {
                        final uri = Uri.parse('mailto:support@claimsupport.com?subject=Policy%20Pal%20Assistance');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          if (ctx.mounted) {
                            showAppSnackBar(ctx, 'Contact: support@claimsupport.com', tone: AppTone.info);
                          }
                        }
                      },
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Send Email'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const InfoBanner(
                tone: AppTone.info,
                title: 'Need help understanding a clause?',
                message:
                    'Our coverage evaluator highlights waiting periods, pre-existing disease terms, and financial sub-limits directly from your uploaded policy PDF.',
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutApp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            MediaQuery.of(ctx).padding.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: ctx.palette.primary, borderRadius: AppRadius.mdAll),
                  child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Policy Pal', textAlign: TextAlign.center, style: ctx.text.headlineSmall),
              const SizedBox(height: 2),
              Text('Version 1.0.0 (Build 8) • Production Ready', textAlign: TextAlign.center, style: ctx.text.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Text(
                  'Policy Pal is an AI-powered health insurance claim analysis platform. '
                  'It compares medical prescriptions and treatment plans against insurance policy clauses to evaluate coverage, identify exclusions, and check continuity.',
                  textAlign: TextAlign.start,
                  style: ctx.text.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const InfoBanner(
                tone: AppTone.neutral,
                message:
                    'Disclaimer: Policy Pal provides decision support and informational analysis. It does not replace formal insurance adjudication.',
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out of Policy Pal?',
      message: 'You will need to sign in with your email OTP to access your analysis reports again.',
      confirmLabel: 'Log Out',
      destructive: true,
      icon: Icons.logout_rounded,
    );

    if (!confirmed) return;

    AuthInterceptor.isManualLogout = true;
    try {
      await ApiClient().dio.post('/auth/logout');
    } catch (_) {
      // Proceed with local logout regardless of server state
    }

    await AuthStorage.clearTokens();
    ref.invalidate(authProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(policiesProvider);
    ref.invalidate(prescriptionProvider);
    ref.invalidate(analysisReportProvider);

    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final p = context.palette;

    return Scaffold(
      appBar: const TabAppBar(title: 'Profile', subtitle: 'Your account, preferences and support'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(authProvider);
            await Future.delayed(const Duration(milliseconds: 150));
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
            child: ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Identity Header Card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: authState.when(
                      data: (user) {
                        final name = user?.name ?? 'Alex Morgan';
                        final email = user?.email ?? 'No email provided';
                        final phone = user?.phone;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _Avatar(name: name),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
                                  ),
                                  if (phone != null && phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      phone,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodySmall?.copyWith(color: p.textTertiary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(height: 60, child: LoadingState()),
                      error: (e, _) => ErrorState(
                        compact: true,
                        title: 'Couldn\'t load your profile',
                        message: friendlyErrorMessage(e),
                        onRetry: () => ref.invalidate(authProvider),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.section),
                  const _GroupLabel('Account Settings'),
                  _MenuGroup(
                    children: [
                      _MenuTile(
                        icon: Icons.badge_outlined,
                        title: 'Account Information',
                        subtitle: 'Personal details and verification status',
                        onTap: () {
                          final user = authState.value;
                          if (user != null) {
                            _showAccountInfo(context, user);
                          } else {
                            context.push('/settings');
                          }
                        },
                      ),
                      _MenuTile(
                        icon: Icons.edit_note_rounded,
                        title: 'Edit Profile',
                        subtitle: 'Update your display name and email',
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.section),
                  const _GroupLabel('Preferences & Support'),
                  _MenuGroup(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                        child: Row(
                          children: [
                            IconTile(
                              icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                              size: 36,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dark Mode', style: context.text.titleSmall),
                                  Text(
                                    isDark ? 'Dark theme enabled' : 'Light theme enabled',
                                    style: context.text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isDark,
                              onChanged: (_) {
                                ref.read(themeProvider.notifier).toggleTheme();
                              },
                            ),
                          ],
                        ),
                      ),
                      _MenuTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        subtitle: 'FAQs, claim guidelines, and customer support',
                        onTap: () => _showHelpSupport(context),
                      ),
                      _MenuTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About Policy Pal',
                        subtitle: 'App version, engine info, and terms',
                        onTap: () => _showAboutApp(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Logout Action
                  OutlinedButton.icon(
                    onPressed: () => _logout(context, ref),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Log Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.danger.fg,
                      backgroundColor: p.danger.bg,
                      side: BorderSide(color: p.danger.border),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final initials = _initials;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: context.text.titleLarge?.copyWith(
          color: p.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;

  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.xs),
      child: Text(text.toUpperCase(), style: context.text.labelSmall),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, indent: 60, color: p.border));
      rows.add(children[i]);
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Column(children: rows),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.title, required this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          child: Row(
            children: [
              IconTile(icon: icon, size: 36),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.text.bodySmall),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
