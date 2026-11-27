import 'package:claimsupport/core/localization/localization.dart';
import 'package:flutter/material.dart';

import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';

class AppSheetList extends StatelessWidget {
  const AppSheetList({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: DsSpace.s8,
    children: rows,
  );
}

class AppSheetKeyValue extends StatelessWidget {
  const AppSheetKeyValue({super.key, required this.label, required this.value, this.monospace = false});

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppTextStyles.bodyStrong.copyWith(color: c.textPrimary);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderDivider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.s8),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.reportBody.copyWith(color: c.textSecondary),
                ),
              ),
              const SizedBox(width: DsSpace.s12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.62),
                child: monospace
                    ? SelectableText(
                        value,
                        textAlign: TextAlign.end,
                        style: style.copyWith(fontFamily: AppTextStyles.mono),
                      )
                    : Text(value, textAlign: TextAlign.end, style: style),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSheetFieldList extends StatelessWidget {
  const AppSheetFieldList({super.key, required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final valueStyle = AppTextStyles.subheadStrong.copyWith(color: colors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        children: [
          Text(label, style: AppTextStyles.label.copyWith(color: colors.textSecondary)),
          for (final value in values) Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

class AppSheetConfirmation extends StatelessWidget {
  const AppSheetConfirmation({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: DsSpace.s8,
    children: [
      Text(message, style: AppTextStyles.bodyStrong.copyWith(color: context.colors.textPrimary)),
      AppButton(label: actionLabel, onPressed: onConfirm),
      AppButton(label: context.l10n.sharedCancel, style: AppButtonStyle.secondary, onPressed: onCancel),
    ],
  );
}
