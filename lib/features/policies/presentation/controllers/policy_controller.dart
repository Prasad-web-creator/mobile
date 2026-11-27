import 'package:claimsupport/core/models/retained_page_notifier.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/core/models/pagination_response.dart';

final policiesProvider = AsyncNotifierProvider<PoliciesNotifier, PaginationResponse<Policy>>(() {
  return PoliciesNotifier();
});

class PoliciesNotifier extends RetainedPageNotifier<Policy> {
  String _searchQuery = '';
  static const int _limit = 10;

  @override
  Future<PaginationResponse<Policy>> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return super.build();
  }

  @override
  Future<PaginationResponse<Policy>> fetchPage(int page) {
    final repository = ref.read(policyRepositoryProvider);
    return repository.getPolicies(page: page, limit: _limit, search: _searchQuery);
  }

  Future<void> fetchPolicies({bool isRefresh = false}) => refreshPage(firstPage: isRefresh);

  Timer? _debounceTimer;

  void search(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchQuery = query;
      fetchPolicies(isRefresh: true);
    });
  }

  Future<void> deletePolicy(String id) async {
    final repository = ref.read(policyRepositoryProvider);
    await repository.deletePolicy(id);
    if (ref.mounted) removeLocally((item) => item.id == id);
  }

  Future<int> deletePolicies(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final repository = ref.read(policyRepositoryProvider);
    final deleted = await repository.deleteBatchPolicies(ids);
    if (ref.mounted) {
      final targets = ids.toSet();
      final updated = removeLocally((item) => targets.contains(item.id));
      if (updated != null && updated.docs.length < updated.totalDocs) {
        unawaited(silentRefreshFirstPage(keepLoadedPages: true));
      }
    }
    return deleted;
  }
}
