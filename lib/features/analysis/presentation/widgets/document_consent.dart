import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:flutter/material.dart';

Future<bool> confirmDocumentConsent(BuildContext context) async =>
    await AppSheet.show<bool>(
      context: context,
      title: context.l10n.analysisBeforeBegin,
      bodyBuilder: (context) => AppSheetConfirmation(
        message: context.l10n.analysisDocumentConsent,
        actionLabel: context.l10n.analysisAcceptContinue,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    ) ??
    false;
