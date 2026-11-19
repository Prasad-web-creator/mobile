import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/features/logs/presentation/controllers/log_controller.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  IconData _getIconForEntity(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'policy':
        return Icons.policy_outlined;
      case 'prescription':
        return Icons.medical_services_outlined;
      case 'medicalreport':
        return Icons.description_outlined;
      case 'medicalbill':
        return Icons.receipt_long_outlined;
      case 'analysisreport':
        return Icons.analytics_outlined;
      case 'user':
        return Icons.person_outline_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  AppTone _toneForEntity(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'analysisreport':
        return AppTone.success;
      case 'prescription':
      case 'medicalreport':
      case 'medicalbill':
        return AppTone.verify;
      case 'user':
        return AppTone.neutral;
      default:
        return AppTone.brand;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logState = ref.watch(logProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Logs')),
      body: SafeArea(
        child: logState.when(
          data: (pagination) {
            final logs = pagination.docs;
            if (logs.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(logProvider.notifier).fetchLogs(isRefresh: true);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: AppSpacing.xxl),
                    EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No activity logs found.',
                      message: 'Uploads, analyses and account changes will appear here.',
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(logProvider.notifier).fetchLogs(isRefresh: true);
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
                itemCount: logs.length + (pagination.hasNextPage ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == logs.length) {
                    ref.read(logProvider.notifier).loadNextPage();
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)),
                      ),
                    );
                  }

                  final log = logs[index];
                  final dateStr = DateFormat.yMMMd().add_jm().format(log.createdAt);

                  return ContentWidth(
                    child: AppCard(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          IconTile(
                            icon: _getIconForEntity(log.entityType),
                            tone: _toneForEntity(log.entityType),
                            size: 40,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log.action, style: context.text.titleSmall),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.schedule_rounded, size: 13, color: context.palette.textTertiary),
                                    const SizedBox(width: 4),
                                    Flexible(child: Text(dateStr, style: context.text.bodySmall)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const LoadingState(message: 'Loading activity…'),
          error: (err, stack) => ErrorState(
            title: 'Couldn\'t load activity',
            message: friendlyErrorMessage(err),
            onRetry: () => ref.invalidate(logProvider),
          ),
        ),
      ),
    );
  }
}
