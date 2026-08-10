import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/features/logs/presentation/controllers/log_controller.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  IconData _getIconForEntity(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'policy':
        return Icons.policy;
      case 'prescription':
        return Icons.medical_services;
      case 'medicalreport':
        return Icons.description;
      case 'medicalbill':
        return Icons.receipt;
      case 'analysisreport':
        return Icons.analytics;
      case 'user':
        return Icons.person;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logState = ref.watch(logProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: logState.when(
            data: (pagination) {
              final logs = pagination.docs;
              if (logs.isEmpty) {
                return const Center(
                  child: Text('No activity logs found.'),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(logProvider.notifier).fetchLogs(isRefresh: true);
                },
                child: ListView.builder(
                  itemCount: logs.length + (pagination.hasNextPage ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == logs.length) {
                      ref.read(logProvider.notifier).loadNextPage();
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    
                    final log = logs[index];
                    final dateStr = DateFormat.yMMMd().add_jm().format(log.createdAt);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Icon(
                            _getIconForEntity(log.entityType),
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(dateStr),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ),
    );
  }
}
