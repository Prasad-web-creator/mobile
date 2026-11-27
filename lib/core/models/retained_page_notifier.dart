import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the last successful page available when a refresh or pagination fails.
abstract class RetainedPageNotifier<T> extends AsyncNotifier<PaginationResponse<T>> {
  PaginationResponse<T>? _cachedPage;
  int _request = 0;

  PaginationResponse<T>? get cachedPage => _cachedPage;

  void seedCachedPage(PaginationResponse<T>? page) {
    _cachedPage = page;
  }

  Future<PaginationResponse<T>> fetchPage(int page);

  @override
  Future<PaginationResponse<T>> build() async {
    final request = ++_request;
    _cachedPage = null;
    final first = await fetchPage(1);
    if (ref.mounted && request == _request) _cachedPage = first;
    return first;
  }

  Future<void> refreshPage({bool firstPage = true}) async {
    final request = ++_request;
    final activeRef = ref;
    final page = firstPage ? 1 : (_cachedPage?.page ?? 1);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => fetchPage(page));
    if (!activeRef.mounted || request != _request) return;
    if (result.value case final data?) _cachedPage = data;
    state = result;
  }

  /// Refreshes page 1 silently without flipping [state] to [AsyncLoading],
  /// so cached lists never flash a loading spinner.
  Future<PaginationResponse<T>?> silentRefreshFirstPage({bool keepLoadedPages = false}) async {
    final request = ++_request;
    final activeRef = ref;
    final loadedPages = keepLoadedPages ? _cachedPage?.page ?? 1 : 1;
    try {
      var fresh = await fetchPage(1);
      while (fresh.hasNextPage && fresh.page < loadedPages && activeRef.mounted && request == _request) {
        fresh = fresh.append(await fetchPage(fresh.page + 1));
      }
      if (!activeRef.mounted || request != _request) return null;
      _cachedPage = fresh;
      state = AsyncData(fresh);
      return fresh;
    } catch (_) {
      return null;
    }
  }

  Future<PaginationResponse<T>> fetchAndKeepPage(int page) async {
    final previous = _cachedPage;
    final request = _request;
    final activeRef = ref;
    final next = await fetchPage(page);
    if (activeRef.mounted && request == _request && identical(previous, _cachedPage) && previous?.page == page - 1) {
      final accumulated = previous!.append(next);
      _cachedPage = accumulated;
      state = AsyncData(accumulated);
    }
    return next;
  }

  /// Removes matching records from the current visible list without reloading
  /// the whole list or showing a spinner.
  PaginationResponse<T>? removeLocally(bool Function(T item) shouldRemove) {
    final current = state.value ?? _cachedPage;
    if (current == null) return null;
    final remaining = current.docs.where((item) => !shouldRemove(item)).toList();
    final removedCount = current.docs.length - remaining.length;
    if (removedCount <= 0) return current;
    _request++;
    final newTotal = (current.totalDocs - removedCount).clamp(0, current.totalDocs);
    final newTotalPages = newTotal == 0 ? 1 : (newTotal / current.limit).ceil();
    final next = PaginationResponse<T>(
      docs: remaining,
      totalDocs: newTotal,
      limit: current.limit,
      totalPages: newTotalPages,
      page: current.page > newTotalPages ? newTotalPages : current.page,
      hasPrevPage: current.hasPrevPage,
      hasNextPage: current.page < newTotalPages,
    );
    _cachedPage = next;
    state = AsyncData(next);
    return next;
  }

  Future<void> loadNextPage() async {
    final previous = state.value ?? _cachedPage;
    if (state.isLoading || previous == null || !previous.hasNextPage) return;
    final request = ++_request;
    final activeRef = ref;
    _cachedPage = previous;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final next = await fetchPage(previous.page + 1);
      return previous.append(next);
    });
    if (!activeRef.mounted || request != _request) return;
    if (result.value case final data?) _cachedPage = data;
    state = result;
  }
}
