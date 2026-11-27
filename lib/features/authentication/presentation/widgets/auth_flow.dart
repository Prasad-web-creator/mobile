import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_design_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.onBack,
    this.showLogo = false,
    this.busy = false,
    this.footer,
  });

  final String title;
  final List<Widget> body;
  final String actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onBack;
  final bool showLogo;
  final bool busy;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brightness = Theme.of(context).brightness;
    final overlay = brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return AppDesignSurface(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlay.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colors.backgroundHome,
        ),
        child: Scaffold(
          backgroundColor: colors.backgroundHome,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/backgrounds/auth_bg_${brightness.name}.png',
                    height: DsSize.authBackgroundHeight,
                    fit: BoxFit.fill,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ListView(
                            key: ValueKey(title),
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              DsSpace.s20,
                              showLogo ? 72 : DsSpace.s24,
                              DsSpace.s20,
                              DsSpace.s16,
                            ),
                            children: [
                              if (showLogo) ...[
                                const Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: AuthBrandMark(size: 44),
                                ),
                                const SizedBox(height: DsSpace.s32),
                              ],
                              if (onBack != null) ...[
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: AppIconButton(
                                    icon: AppIcons.caretLeft,
                                    label: MaterialLocalizations.of(context).backButtonTooltip,
                                    onPressed: busy ? null : onBack,
                                  ),
                                ),
                                const SizedBox(height: DsSpace.s16),
                              ],
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: AppTextStyles.largeTitle.copyWith(color: colors.textPrimary),
                                ),
                              ),
                              const SizedBox(height: DsSpace.s6),
                              ...body,
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            DsSpace.s20,
                            DsSpace.s8,
                            DsSpace.s20,
                            DsSpace.s24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: DsSpace.s12,
                            children: [
                              ?footer,
                              if (actionLabel.isNotEmpty)
                                AppButton(label: actionLabel, busy: busy, onPressed: onAction),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .24),
    child: Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.email = false,
    this.enabled = true,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool email;
  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DsShape.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(label, style: AppTextStyles.captionStrong.copyWith(color: colors.textPrimary)),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: email ? TextInputType.emailAddress : TextInputType.name,
          textCapitalization: email ? TextCapitalization.none : TextCapitalization.words,
          autofillHints: [email ? AutofillHints.email : AutofillHints.name],
          autocorrect: !email,
          inputFormatters: email ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))] : null,
          textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.go,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          style: AppTextStyles.bodyStrong.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: email ? 'you@example.com' : context.l10n.authYourName,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            enabledBorder: border(colors.borderStrong),
            focusedBorder: border(colors.buttonPrimary, 2),
            disabledBorder: border(colors.borderSubtle),
          ),
        ),
      ],
    );
  }
}

class AuthTextAction extends StatelessWidget {
  const AuthTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.prefix = '',
    this.center = false,
  });

  final String label;
  final VoidCallback? onTap;
  final String prefix;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: center ? Alignment.center : AlignmentDirectional.centerStart,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DsShape.radiusXs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.s8),
          child: Text.rich(
            TextSpan(
              text: prefix,
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    color: onTap == null ? colors.textTertiary : colors.textLink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            style: AppTextStyles.label.copyWith(color: colors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class AuthCodeForm extends StatelessWidget {
  const AuthCodeForm({
    super.key,
    required this.email,
    required this.length,
    required this.controller,
    required this.secondsLeft,
    required this.busy,
    required this.onChangeEmail,
    required this.onResend,
    required this.onVerify,
    this.error,
  });

  final String email;
  final int length;
  final TextEditingController controller;
  final int secondsLeft;
  final bool busy;
  final String? error;
  final VoidCallback onChangeEmail;
  final VoidCallback onResend;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final minutes = secondsLeft ~/ 60;
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.authCodeEnter(length),
          style: AppTextStyles.subheadRegular.copyWith(color: c.textSecondary),
        ),
        SelectableText(email, style: AppTextStyles.subheadStrong.copyWith(color: c.textPrimary)),
        AuthTextAction(label: context.l10n.authChangeEmail, onTap: busy ? null : onChangeEmail),
        const SizedBox(height: DsSpace.s20),
        Stack(
          children: [
            ExcludeSemantics(
              child: ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, _) => Row(
                  spacing: DsSpace.s8,
                  children: [
                    for (var index = 0; index < length; index++)
                      Expanded(
                        child: Container(
                          height: 58,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.surfaceCard,
                            shape: DsShape.shape(
                              DsShape.radiusMd,
                              side: BorderSide(
                                color: error != null
                                    ? c.statusNotCovered
                                    : index == value.text.length
                                    ? c.buttonPrimary
                                    : c.borderStrong,
                                width: error != null || index == value.text.length ? 1.6 : 1,
                              ),
                            ),
                          ),
                          child: index < value.text.length
                              ? Text(
                                  value.text[index],
                                  style: AppTextStyles.title.copyWith(color: c.textPrimary),
                                )
                              : index == value.text.length && error == null
                              ? SizedBox(width: 1, height: 23, child: ColoredBox(color: c.buttonPrimary))
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: Semantics(
                  label: context.l10n.authVerificationCode,
                  child: TextField(
                    controller: controller,
                    readOnly: busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(length),
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onVerify(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.s12),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(error!, style: AppTextStyles.label.copyWith(color: c.statusNotCovered)),
          ),
        if (secondsLeft > 0)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.s4),
            child: Text(
              context.l10n.authCodeResendTimer('$minutes:$seconds'),
              style: AppTextStyles.label.copyWith(color: c.textSecondary),
            ),
          )
        else
          AuthTextAction(label: context.l10n.authResendCode, onTap: busy ? null : onResend),
      ],
    );
  }
}
