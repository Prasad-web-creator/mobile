import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/core/models/retained_page_notifier.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';

/// Account-scoped cache for the History list (in memory + SharedPreferences)
/// so History renders immediately with no spinner after the first load.
final historyCacheProvider = Provider((ref) {
  final cache = HistoryCache();
  ref.listen(authProvider.select((user) => user.value?.id), (previous, next) {
    if (previous != null && previous != next) cache.clear(account: previous);
  });
  return cache;
});

class HistoryCache {
  static const _prefsPrefix = 'cached_history_page_v1_';

  ({String account, PaginationResponse<AnalysisReportGroup> page})? _memory;

  PaginationResponse<AnalysisReportGroup>? read(String? account) {
    if (account == null || account.isEmpty) return null;
    final mem = _memory;
    if (mem != null && mem.account == account) return mem.page;
    final raw = SharedPrefs.maybeInstance?.getString('$_prefsPrefix$account');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        final page = PaginationResponse.fromJson(map, (json) => AnalysisReportGroup.fromJson(json));
        _memory = (account: account, page: page);
        return page;
      }
    } catch (e) {
      debugPrint('[HistoryCache] Failed to decode cached history: $e');
    }
    return null;
  }

  void save(String? account, PaginationResponse<AnalysisReportGroup> page) {
    if (account == null || account.isEmpty) return;
    _memory = (account: account, page: page);
    final payload = {
      'docs': [for (final doc in page.docs) doc.toJson()],
      'totalDocs': page.totalDocs,
      'limit': page.limit,
      'totalPages': page.totalPages,
      'page': page.page,
      'hasPrevPage': page.hasPrevPage,
      'hasNextPage': page.hasNextPage,
    };
    unawaited(SharedPrefs.maybeInstance?.setString('$_prefsPrefix$account', jsonEncode(payload)).then<void>((_) {}));
  }

  void clear({String? account}) {
    final target = account ?? _memory?.account;
    _memory = null;
    if (target != null && target.isNotEmpty) {
      unawaited(SharedPrefs.maybeInstance?.remove('$_prefsPrefix$target').then<void>((_) {}));
    }
  }
}

/// Drives the Coverage Analysis Reports list (History tab).
///
/// Each item is an analysis *group*: a multi-policy analysis carries all of its
/// policy results, a single-policy analysis is a group of one.
class AnalysisReportNotifier extends RetainedPageNotifier<AnalysisReportGroup> {
  static const int _limit = 10;
  bool _backgroundRefreshing = false;

  @override
  Future<PaginationResponse<AnalysisReportGroup>> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    final account = ref.watch(authProvider.select((user) => user.value?.id));
    final cache = ref.read(historyCacheProvider);
    final cached = cache.read(account);
    if (cached != null) {
      seedCachedPage(cached);
      ref.keepAlive();
      unawaited(refreshInBackground());
      return cached;
    }
    final first = await super.build();
    if (ref.mounted) {
      ref.keepAlive();
      cache.save(account, first);
    }
    return first;
  }

  @override
  Future<PaginationResponse<AnalysisReportGroup>> fetchPage(int page) {
    final repository = ref.read(analysisReportRepositoryProvider);
    return repository.getAnalysisReportGroups(page: page, limit: _limit);
  }

  Future<void> fetchAnalysisReports({bool isRefresh = false}) async {
    await refreshPage(firstPage: isRefresh);
    if (!ref.mounted) return;
    final data = state.value;
    if (data != null && data.page == 1) {
      ref.read(historyCacheProvider).save(ref.read(authProvider).value?.id, data);
    }
  }

  /// Refreshes History in the background when the tab opens or a check finishes,
  /// without blanking the cached list or showing a spinner.
  Future<void> refreshInBackground() async {
    if (_backgroundRefreshing) return;
    _backgroundRefreshing = true;
    try {
      final fresh = await silentRefreshFirstPage(keepLoadedPages: true);
      if (fresh != null && ref.mounted) {
        ref.read(historyCacheProvider).save(ref.read(authProvider).value?.id, fresh);
      }
    } finally {
      _backgroundRefreshing = false;
    }
  }

  Timer? _debounceTimer;

  void search(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      fetchAnalysisReports(isRefresh: true);
    });
  }

  /// Delete one analysis group (and every report inside it) without reloading the list.
  Future<void> deleteReport(String groupId) async {
    final repository = ref.read(analysisReportRepositoryProvider);
    await repository.deleteAnalysisGroup(groupId);
    if (!ref.mounted) return;
    final next = removeLocally((g) => g.groupId == groupId);
    if (next != null) {
      ref.read(historyCacheProvider).save(ref.read(authProvider).value?.id, next);
      if (next.docs.length < next.totalDocs) unawaited(refreshInBackground());
    }
  }

  /// Delete selected analysis groups and remove them from the cached list in-place.
  Future<int> deleteReports(List<String> groupIds) async {
    if (groupIds.isEmpty) return 0;
    final repository = ref.read(analysisReportRepositoryProvider);
    final deleted = await repository.deleteBatchAnalysisGroups(groupIds);
    if (!ref.mounted) return deleted;
    final targetIds = groupIds.toSet();
    final next = removeLocally((g) => targetIds.contains(g.groupId));
    if (next != null) {
      ref.read(historyCacheProvider).save(ref.read(authProvider).value?.id, next);
      if (next.docs.length < next.totalDocs) unawaited(refreshInBackground());
    }
    return deleted;
  }
}

final analysisReportProvider = AsyncNotifierProvider<AnalysisReportNotifier, PaginationResponse<AnalysisReportGroup>>(
  () {
    return AnalysisReportNotifier();
  },
);
