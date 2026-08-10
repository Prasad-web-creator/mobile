import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/logs/data/models/activity_log.dart';
import 'package:claimsupport/features/logs/data/repositories/log_repository.dart';

class LogNotifier extends AsyncNotifier<PaginatedActivityLogs> {
  int _currentPage = 1;
  static const int _limit = 20;

  @override
  Future<PaginatedActivityLogs> build() async {
    return _fetchLogs();
  }

  Future<PaginatedActivityLogs> _fetchLogs() async {
    final repository = ref.read(logRepositoryProvider);
    final newPagination = await repository.getLogs(page: _currentPage, limit: _limit);

    // If it's page 1, just return
    if (_currentPage == 1) {
      return newPagination;
    }

    // Otherwise append to current data
    final currentData = state.value;
    if (currentData != null) {
      final updatedDocs = <ActivityLog>[...currentData.docs, ...newPagination.docs];
      return PaginatedActivityLogs(
        docs: updatedDocs,
        totalDocs: newPagination.totalDocs,
        limit: newPagination.limit,
        page: newPagination.page,
        totalPages: newPagination.totalPages,
        hasNextPage: newPagination.hasNextPage,
      );
    }
    return newPagination;
  }

  Future<void> fetchLogs({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchLogs());
  }

  void loadNextPage() {
    final currentState = state.value;
    if (currentState != null && currentState.hasNextPage) {
      _currentPage++;
      fetchLogs();
    }
  }
}

final logProvider = AsyncNotifierProvider<LogNotifier, PaginatedActivityLogs>(() {
  return LogNotifier();
});
