import 'package:claimsupport/core/models/retained_page_notifier.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:claimsupport/core/models/pagination_response.dart';

class PrescriptionNotifier extends RetainedPageNotifier<Prescription> {
  String _currentSearch = '';

  static const int _limit = 10;

  @override
  Future<PaginationResponse<Prescription>> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return super.build();
  }

  @override
  Future<PaginationResponse<Prescription>> fetchPage(int page) {
    final repository = ref.read(prescriptionRepositoryProvider);
    return repository.getPrescriptions(page: page, limit: _limit, search: _currentSearch);
  }

  Future<void> fetchPrescriptions({bool isRefresh = false}) => refreshPage(firstPage: isRefresh);

  Timer? _debounceTimer;

  void search(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _currentSearch = query;
      fetchPrescriptions(isRefresh: true);
    });
  }

  Future<void> deletePrescription(String id) async {
    final repository = ref.read(prescriptionRepositoryProvider);
    await repository.deletePrescription(id);
    if (ref.mounted) removeLocally((item) => item.id == id);
  }

  Future<int> deletePrescriptions(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final repository = ref.read(prescriptionRepositoryProvider);
    final deleted = await repository.deleteBatchPrescriptions(ids);
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

final prescriptionProvider = AsyncNotifierProvider<PrescriptionNotifier, PaginationResponse<Prescription>>(() {
  return PrescriptionNotifier();
});
