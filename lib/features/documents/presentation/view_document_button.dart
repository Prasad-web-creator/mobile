import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ViewDocumentButton extends StatelessWidget {
  const ViewDocumentButton({super.key, required this.fileId, required this.title});

  final String fileId;
  final String title;

  @override
  Widget build(BuildContext context) => AppButton(
    label: 'View document',
    style: AppButtonStyle.secondary,
    onPressed: () {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(Uri(pathSegments: ['', 'view-pdf', fileId], queryParameters: {'title': title}).toString());
    },
  );
}
