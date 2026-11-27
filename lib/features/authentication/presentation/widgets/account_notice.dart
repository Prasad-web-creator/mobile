import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:flutter/material.dart';

enum AccountNotice {
  terms,
  privacy;

  String title(AppLocalizations l10n) => switch (this) {
    terms => l10n.authTermsTitle,
    privacy => l10n.authPrivacyTitle,
  };

  List<String> paragraphs(AppLocalizations l10n) => switch (this) {
    terms => [l10n.authTermsFirst, l10n.authTermsSecond],
    privacy => [l10n.authPrivacyFirst, l10n.authPrivacySecond],
  };

  Future<void> show(BuildContext context) => AppSheet.show<void>(
    context: context,
    title: title(context.l10n),
    showClose: true,
    bodyBuilder: (context) => AppSheetList(
      rows: [
        for (final line in paragraphs(context.l10n))
          Text(line, style: AppTextStyles.bodyStrong.copyWith(color: context.colors.textPrimary)),
      ],
    ),
  );
}
