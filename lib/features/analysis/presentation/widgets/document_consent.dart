import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:flutter/material.dart';

Future<bool> confirmDocumentConsent(BuildContext context) async =>
    await AppSheet.show<bool>(
      context: context,
      title: 'Before we begin',
      bodyBuilder: (context) => AppSheetConfirmation(
        message:
            'I have permission to use this document. I agree that Policy Pal may store it and '
            'read it with OCR and send extracted text to Google Gemini for analysis. '
            'The result is for reference. Policy Pal does not submit a claim, and only the insurer can approve it.',
        actionLabel: 'Accept and continue',
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    ) ??
    false;
