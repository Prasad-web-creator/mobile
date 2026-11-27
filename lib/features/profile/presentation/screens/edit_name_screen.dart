import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/authentication/presentation/widgets/auth_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EditNameScreen extends ConsumerWidget {
  const EditNameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider);
    void back() => context.canPop() ? context.pop() : context.go('/profile');
    if (account.value case final user?) {
      return _EditNameForm(key: ValueKey(user.id), user: user, onBack: back);
    }
    return AuthPage(
      title: context.l10n.accountEditName,
      onBack: back,
      actionLabel: '',
      onAction: null,
      body: [
        if (account.isLoading)
          const AppSkeleton(kind: AppSkeletonKind.row)
        else
          AppInlineBanner(
            kind: AppInlineBannerKind.error,
            message: context.l10n.accountLoadError,
            onRetry: () => ref.invalidate(authProvider),
          ),
      ],
    );
  }
}

class _EditNameForm extends ConsumerStatefulWidget {
  const _EditNameForm({super.key, required this.user, required this.onBack});

  final User user;
  final VoidCallback onBack;

  @override
  ConsumerState<_EditNameForm> createState() => _EditNameFormState();
}

class _EditNameFormState extends ConsumerState<_EditNameForm> {
  late final _name = TextEditingController(text: widget.user.name);
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (_saving || name.isEmpty || name == widget.user.name.trim()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(authProvider.notifier).updateProfile(name, widget.user.email);
      if (mounted) widget.onBack();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder(
      valueListenable: _name,
      builder: (context, value, _) => AuthPage(
        title: context.l10n.accountEditName,
        onBack: widget.onBack,
        actionLabel: context.l10n.accountSave,
        onAction: value.text.trim().isEmpty || value.text.trim() == widget.user.name.trim() ? null : _save,
        busy: _saving,
        body: [
          const SizedBox(height: DsSpace.s16),
          AuthField(
            label: context.l10n.authFullName,
            controller: _name,
            enabled: !_saving,
            onSubmitted: _save,
          ),
          const SizedBox(height: DsSpace.s16),
          Text(context.l10n.authEmail, style: AppTextStyles.captionStrong.copyWith(color: c.textPrimary)),
          const SizedBox(height: DsSpace.s8),
          DecoratedBox(
            decoration: ShapeDecoration(
              color: dark ? c.surfaceCard : c.buttonDisabled,
              shape: DsShape.shape(DsShape.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: SelectableText(
                widget.user.email,
                style: AppTextStyles.bodyStrong.copyWith(color: c.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: DsSpace.s8),
          Text(
            context.l10n.accountEmailReadOnly,
            style: AppTextStyles.captionRegular.copyWith(color: c.textSecondary),
          ),
          if (_failed) ...[
            const SizedBox(height: DsSpace.s12),
            AppInlineBanner(kind: AppInlineBannerKind.error, message: context.l10n.accountSaveNameError),
          ],
        ],
      ),
    );
  }
}
