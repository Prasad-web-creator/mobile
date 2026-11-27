import 'package:claimsupport/core/config/app_config_provider.dart';
import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_design_surface.dart';
import 'package:claimsupport/core/design/widgets/app_pressable.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/network/auth_interceptor.dart';
import 'package:claimsupport/core/theme/theme_provider.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/core/utils/device_app_info.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/account_notice.dart';
import 'package:claimsupport/features/checks/presentation/check_completion_monitor.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/documents/presentation/saved_list_feedback.dart';
import 'package:claimsupport/features/home/presentation/controllers/home_checks_provider.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

final _appVersionProvider = FutureProvider((ref) => DeviceAppInfo.getAppVersion());

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    try {
      await ref.refresh(authProvider.future).then<void>((_) {});
    } catch (_) {
      // The provider exposes the failure and any previous account data.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider);
    final mode = ref.watch(themeProvider);
    final version = ref.watch(_appVersionProvider).value;
    final user = account.value;
    final c = context.colors;
    final overlay = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: c.backgroundPage,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s24, DsSpace.s16, DsSpace.s16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppIconButton(
                    icon: AppIcons.caretLeft,
                    label: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s24),
                    children: [
                      if (account.hasError && !account.isLoading)
                        SavedListError(
                          error: account.error,
                          offlineMessage: user == null
                              ? "You're offline."
                              : "You're offline. Showing saved account details.",
                          message: "Couldn't load your account.",
                          onRetry: () => _refresh(ref),
                        ),
                      if (user != null) ...[
                        _Identity(user: user),
                        const SizedBox(height: DsSpace.s16),
                        AppPressableSurface(
                          radius: DsShape.radiusFull,
                          color: c.surfaceCard,
                          border: BorderSide(color: c.borderSubtle),
                          onTap: () => context.push('/profile/edit-name'),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: DsSize.controlLg),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: DsSpace.s8,
                              children: [
                                Icon(AppIcons.pencil, size: DsSize.iconSm, color: c.textPrimary),
                                Text(
                                  'Edit name',
                                  style: AppTextStyles.label.copyWith(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (account.isLoading)
                        const AppSkeleton(kind: AppSkeletonKind.row)
                      else if (!account.hasError)
                        const SavedListMessage('Account details are unavailable.'),
                      const SizedBox(height: 28),
                      const _ProfileLabel('Preferences'),
                      const SizedBox(height: DsSpace.s8),
                      _ProfileGroup(
                        children: [
                          _ProfileRow(
                            icon: AppIcons.appearance,
                            label: 'Appearance',
                            detail: _appearanceLabel(mode),
                            onTap: () => _appearance(context),
                          ),
                          const _NotificationRow(),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const _ProfileLabel('Help'),
                      const SizedBox(height: DsSpace.s8),
                      _ProfileGroup(
                        children: [
                          _ProfileRow(icon: AppIcons.help, label: 'Help and support', onTap: () => _help(context)),
                          _ProfileRow(
                            icon: AppIcons.fileText,
                            label: 'Terms of use',
                            onTap: () => AccountNotice.terms.show(context),
                          ),
                          _ProfileRow(
                            icon: AppIcons.lock,
                            label: 'Privacy policy',
                            onTap: () => AccountNotice.privacy.show(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: DsSpace.s20),
                      _ProfileGroup(
                        children: [
                          _ProfileRow(
                            icon: AppIcons.signOut,
                            label: 'Log out',
                            showChevron: false,
                            onTap: () => _logout(context, ref),
                          ),
                        ],
                      ),
                      if (version != null) ...[
                        const SizedBox(height: DsSpace.s24),
                        Text(
                          'Policy Pal · Version $version',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _appearance(BuildContext context) => AppSheet.show<void>(
    context: context,
    title: 'Appearance',
    showClose: true,
    bodyBuilder: (_) => Consumer(
      builder: (context, ref, _) {
        final selected = ref.watch(themeProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values) ...[
              if (mode != ThemeMode.system) const _ProfileDivider(),
              _AppearanceRow(
                label: _appearanceLabel(mode),
                hint: mode == ThemeMode.system ? "Match your phone's setting" : null,
                selected: mode == selected,
                onTap: () => ref.read(themeProvider.notifier).selectTheme(mode),
              ),
            ],
          ],
        );
      },
    ),
  );

  static String _appearanceLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  void _help(BuildContext context) {
    AppSheet.show<void>(
      context: context,
      title: 'Help and support',
      showClose: true,
      bodyBuilder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(supportEmailProvider);
          final email = state.value;
          return AppSheetList(
            rows: [
              if (state.isLoading) const AppSkeleton(kind: AppSkeletonKind.row),
              if (!state.isLoading && email == null)
                SavedListError(
                  error: state.error,
                  offlineMessage: "You're offline.",
                  message: 'Support contact is unavailable.',
                  onRetry: () => ref.invalidate(supportEmailProvider),
                ),
              if (email != null) ...[
                AppSheetKeyValue(label: 'Support email', value: email),
                AppButton(
                  label: 'Send email',
                  onPressed: () async {
                    final opened = await launchUrl(
                      Uri(scheme: 'mailto', path: email, query: 'subject=Policy%20Pal%20Assistance'),
                    );
                    if (!opened) await Clipboard.setData(ClipboardData(text: email));
                  },
                ),
                AppLink(
                  label: 'Copy email',
                  onPressed: () => Clipboard.setData(ClipboardData(text: email)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AppDesignSurface(
        child: Builder(
          builder: (context) {
            final c = context.colors;
            return Dialog(
              backgroundColor: c.surfaceCardRaised,
              insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: DsSpace.s24),
              shape: DsShape.shape(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(DsSpace.s20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Log out?', style: AppTextStyles.headline.copyWith(color: c.textPrimary)),
                      const SizedBox(height: DsSpace.s8),
                      Text(
                        'Your documents and checks stay saved. Log in with your email to see them again.',
                        style: AppTextStyles.label.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: DsSpace.s20),
                      AppButton(
                        label: 'Log out',
                        style: AppButtonStyle.secondary,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                      const SizedBox(height: DsSpace.s6),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    if (approved != true || !context.mounted) return;

    AuthInterceptor.isManualLogout = true;
    final logout = ApiClient().dio.post('/auth/logout').timeout(const Duration(seconds: 3));
    try {
      await logout;
    } catch (_) {
      // An unreachable backend does not prevent local sign-out.
    }
    await AuthStorage.clearTokens();
    if (!context.mounted) return;

    ref.read(homeCheckCacheProvider).clear();
    ref.read(historyCacheProvider).clear();
    ref.invalidate(authProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(homeChecksProvider);
    ref.invalidate(policiesProvider);
    ref.invalidate(prescriptionProvider);
    ref.invalidate(analysisReportProvider);
    context.go('/login');
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = user.name.trim();
    final words = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initialSource = words.isEmpty ? [user.email.trim()] : words;
    final initials = initialSource
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    return Row(
      spacing: DsSpace.s16,
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle),
          child: Text(initials.isEmpty ? '?' : initials, style: AppTextStyles.title.copyWith(color: c.iconActive)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s4,
            children: [
              Text(name.isEmpty ? 'Account' : name, style: AppTextStyles.title.copyWith(color: c.textPrimary)),
              if (user.email.isNotEmpty)
                Text(user.email, style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileLabel extends StatelessWidget {
  const _ProfileLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: DsSpace.s4),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(color: context.colors.textPrimary, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppPressableSurface(
    color: context.colors.surfaceCard,
    border: BorderSide(color: context.colors.borderSubtle),
    radius: DsShape.radiusLg,
    child: Column(
      children: [
        for (final (index, child) in children.indexed) ...[if (index != 0) const _ProfileDivider(), child],
      ],
    ),
  );
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, color: context.colors.borderSubtle);
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.detail,
    this.trailing,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? detail;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPressableSurface(
      color: c.surfaceCard,
      radius: 0,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              Icon(icon, size: DsSize.iconMd, color: c.iconDefault),
              Expanded(
                child: Text(label, style: AppTextStyles.subheadRegular.copyWith(color: c.textPrimary)),
              ),
              if (detail != null) Text(detail!, style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary)),
              if (trailing != null)
                trailing!
              else if (showChevron)
                Icon(AppIcons.caretRight, size: DsSize.iconXs, color: c.iconDefault),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({required this.label, required this.selected, required this.onTap, this.hint});

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      child: AppPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.s12),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Text(label, style: AppTextStyles.subheadRegular.copyWith(color: c.textPrimary)),
                    if (hint != null) Text(hint!, style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? c.buttonPrimary : c.borderStrong, width: selected ? 7 : 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends ConsumerStatefulWidget {
  const _NotificationRow();

  @override
  ConsumerState<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends ConsumerState<_NotificationRow> {
  bool _saving = false;

  Future<void> _setEnabled(bool enabled) async {
    if (_saving) return;
    final service = ref.read(checkNotificationsProvider);
    setState(() => _saving = true);
    try {
      await service.setEnabled(enabled);
      if (enabled && await service.requestPermission() == false && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Allow notifications in your phone settings to receive alerts.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Couldn't save your notification setting.")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final service = ref.watch(checkNotificationsProvider);
    return ValueListenableBuilder(
      valueListenable: service.enabled,
      builder: (context, enabled, _) => _ProfileRow(
        icon: AppIcons.bell,
        label: 'Notifications',
        trailing: Semantics(
          label: 'Notifications',
          child: Switch(
            value: enabled,
            activeThumbColor: c.textOnButton,
            activeTrackColor: c.buttonPrimary,
            inactiveThumbColor: c.textOnButton,
            inactiveTrackColor: c.borderStrong,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            onChanged: _saving ? null : _setEnabled,
          ),
        ),
      ),
    );
  }
}
