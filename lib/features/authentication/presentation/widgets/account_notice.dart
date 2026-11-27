import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:flutter/material.dart';

enum AccountNotice {
  terms('Terms of use', [
    'Only upload documents that belong to you or that you have permission to use.',
    'Coverage checks are for reference. Policy Pal does not submit claims. Your insurer makes the final decision.',
  ]),
  privacy('Privacy policy', [
    'Policy Pal stores the documents you upload and processes them to evaluate coverage.',
    'You confirm consent before adding a document.',
  ]);

  const AccountNotice(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;

  Future<void> show(BuildContext context) => AppSheet.show<void>(
    context: context,
    title: title,
    showClose: true,
    bodyBuilder: (context) => AppSheetList(
      rows: [
        for (final line in paragraphs)
          Text(line, style: AppTextStyles.bodyStrong.copyWith(color: context.colors.textPrimary)),
      ],
    ),
  );
}
