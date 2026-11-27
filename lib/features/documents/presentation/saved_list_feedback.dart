import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class SavedListError extends StatelessWidget {
  const SavedListError({
    super.key,
    required this.error,
    required this.offlineMessage,
    required this.message,
    required this.onRetry,
  });

  final Object? error;
  final String offlineMessage;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error;
    final offline =
        failure is DioException &&
        (failure.type == DioExceptionType.connectionError || failure.type == DioExceptionType.connectionTimeout);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.s12),
      child: AppInlineBanner(
        kind: offline ? AppInlineBannerKind.offline : AppInlineBannerKind.error,
        message: offline ? offlineMessage : message,
        onRetry: onRetry,
      ),
    );
  }
}

class SavedListMessage extends StatelessWidget {
  const SavedListMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DsSpace.cardPadding),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: AppTextStyles.bodyStrong.copyWith(color: context.colors.textSecondary),
    ),
  );
}

class SavedListSkeleton extends StatelessWidget {
  const SavedListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: const Column(
      spacing: DsSpace.s8,
      children: [
        AppSkeleton(kind: AppSkeletonKind.row),
        AppSkeleton(kind: AppSkeletonKind.row),
        AppSkeleton(kind: AppSkeletonKind.row),
      ],
    ),
  );
}
