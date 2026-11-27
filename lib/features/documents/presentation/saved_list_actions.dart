import 'package:claimsupport/core/localization/localization.dart';
import 'dart:async';

import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_design_surface.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:flutter/material.dart';

typedef ActiveListSelection = ({String path, VoidCallback close});

final activeListSelectionProvider = Provider((ref) {
  final listener = ValueNotifier<ActiveListSelection?>(null);
  ref.onDispose(listener.dispose);
  return listener;
});

mixin SavedListActions<W extends StatefulWidget, T> on State<W> {
  final _selected = <String>{};
  bool _selecting = false;
  bool _deleting = false;
  bool _paging = false;
  PaginationResponse<T>? _source;
  PaginationResponse<T>? _page;

  ValueNotifier<ActiveListSelection?>? _selectionListener;
  ActiveListSelection? _registration;

  bool get selecting => _selecting;
  bool? itemSelection(String id) => selecting && id.isNotEmpty ? _selected.contains(id) : null;

  @override
  void dispose() {
    _unregisterSelection(deferred: true);
    super.dispose();
  }

  void _unregisterSelection({bool deferred = false}) {
    final listener = _selectionListener;
    final registration = _registration;
    if (listener == null || registration == null) return;
    _registration = null;
    void clear() {
      if (identical(listener.value, registration)) listener.value = null;
    }

    if (deferred) {
      scheduleMicrotask(clear);
    } else {
      clear();
    }
  }

  void beginSelection(String id) {
    if (selecting || listBusy || id.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    HapticFeedback.selectionClick();
    setState(() {
      _selecting = true;
      _selected.add(id);
    });
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      final listener = ProviderScope.containerOf(context, listen: false).read(activeListSelectionProvider);
      final registration = (
        path: router.state.uri.path,
        close: () {
          if (mounted && !_deleting) setState(clearSelection);
        },
      );
      _registration = registration;
      _selectionListener = listener;
      listener.value = registration;
    }
  }

  bool get listBusy => _paging || _deleting;

  PaginationResponse<T>? _failedPage;

  PaginationResponse<T> visiblePage(PaginationResponse<T> source) =>
      identical(source, _source) ? _page ?? source : source;

  void resetList() {
    clearSelection();
    _source = _page = _failedPage = null;
  }

  void clearSelection() {
    _selected.clear();
    _selecting = false;
    _unregisterSelection();
  }

  Future<void> _loadMore(PaginationResponse<T> source, Future<PaginationResponse<T>> Function(int) fetch) async {
    final current = visiblePage(source);
    if (listBusy || !current.hasNextPage) return;
    setState(() {
      _paging = true;
      _failedPage = null;
    });
    try {
      final next = await fetch(current.page + 1);
      if (!mounted) return;
      setState(() {
        _source = source;
        _page = current.append(next);
      });
    } catch (_) {
      if (mounted) setState(() => _failedPage = current);
    } finally {
      if (mounted) setState(() => _paging = false);
    }
  }

  Widget loadOnScroll({
    required PaginationResponse<T>? source,
    required Future<PaginationResponse<T>> Function(int) fetch,
    required bool enabled,
    required Widget child,
  }) => NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      if (!enabled || source == null || notification.depth != 0 || listBusy) return false;
      final page = visiblePage(source);
      final approachingEnd =
          notification.metrics.extentAfter < 200 &&
          (notification is ScrollEndNotification ||
              notification is OverscrollNotification && notification.overscroll > 0);
      if (page.hasNextPage && approachingEnd && !identical(page, _failedPage)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(page, visiblePage(source))) _loadMore(source, fetch);
        });
      }
      return false;
    },
    child: child,
  );

  Widget moreStatus(PaginationResponse<T> source, Future<PaginationResponse<T>> Function(int) fetch) {
    if (_paging) return const Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator()));
    if (identical(visiblePage(source), _failedPage)) {
      return TextButton(onPressed: () => _loadMore(source, fetch), child: Text(context.l10n.sharedRetryLoadingMore));
    }
    return const SizedBox.shrink();
  }

  Widget selectionHeader(
    PaginationResponse<T>? source,
    Future<PaginationResponse<T>> Function(int) fetch,
    String Function(T) idOf,
  ) => Padding(
    padding: EdgeInsets.fromLTRB(DsSpace.screenPadding, DsSpace.screenTop(context), DsSpace.screenPadding, DsSpace.s8),
    child: Row(
      children: [
        AppIconButton(
          icon: AppIcons.close,
          label: context.l10n.sharedExitSelection,
          onPressed: _deleting ? null : () => setState(clearSelection),
        ),
        Expanded(
          child: Text(
            context.l10n.sharedSelectedCount(_selected.length),
            textAlign: TextAlign.center,
            style: AppTextStyles.subheadStrong.copyWith(color: context.colors.textPrimary),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: context.colors.textPrimary,
            backgroundColor: context.colors.surfacePressed,
            textStyle: AppTextStyles.subheadStrong,
          ),
          onPressed: listBusy || source == null ? null : () => _selectAll(source, fetch, idOf),
          child: Text(context.l10n.sharedSelectAll),
        ),
      ],
    ),
  );

  Future<void> _selectAll(
    PaginationResponse<T> source,
    Future<PaginationResponse<T>> Function(int) fetch,
    String Function(T) idOf,
  ) async {
    setState(() => _paging = true);
    try {
      final ids = <String>{};
      var page = visiblePage(source);
      while (true) {
        ids.addAll(page.docs.map(idOf).where((id) => id.isNotEmpty));
        if (!page.hasNextPage || page.docs.isEmpty) break;
        page = await fetch(page.page + 1);
        if (!mounted || !selecting) return;
      }
      if (mounted && selecting) setState(() => _selected.addAll(ids));
    } catch (_) {
      if (mounted) _message(context.l10n.sharedSelectAllFailed);
    } finally {
      if (mounted) setState(() => _paging = false);
    }
  }

  Widget selectionFooter({
    required String singular,
    required String plural,
    required bool isDocument,
    required Future<int> Function(List<String>) delete,
  }) {
    final label = _selected.length == 1 ? singular : plural;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.backgroundPage,
        border: Border(top: BorderSide(color: context.colors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(DsSpace.screenPadding, DsSpace.s8, DsSpace.screenPadding, DsSpace.s8),
        child: AppButton(
          label: context.l10n.sharedRemoveSelected(_selected.length, label),
          icon: AppIcons.trash,
          style: AppButtonStyle.danger,
          onPressed: listBusy || _selected.isEmpty ? null : () => _confirmDelete(singular, plural, isDocument, delete),
        ),
      ),
    );
  }

  void toggleItem(String id) {
    if (listBusy || id.isEmpty) return;
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Future<void> _confirmDelete(
    String singular,
    String plural,
    bool isDocument,
    Future<int> Function(List<String>) delete,
  ) async {
    final ids = _selected.toList();
    final label = ids.length == 1 ? singular : plural;
    setState(() => _deleting = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AppDesignSurface(
          child: Builder(
            builder: (context) => AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: DsSpace.s24),
              titlePadding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s24, DsSpace.s20, DsSpace.s8),
              contentPadding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s20),
              actionsPadding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s16),
              title: Text(context.l10n.sharedConfirmRemoveSelected(ids.length, label), style: AppTextStyles.title),
              content: Text(
                isDocument ? context.l10n.sharedConfirmDeleteDocument : context.l10n.sharedConfirmDelete,
                style: AppTextStyles.subheadRegular.copyWith(color: context.colors.textSecondary),
              ),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: context.l10n.sharedDelete,
                      style: AppButtonStyle.danger,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: context.colors.textPrimary),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(context.l10n.sharedCancel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || confirmed != true) return;
      final deleted = await delete(ids);
      if (!mounted) return;
      setState(resetList);
      _message(
        deleted == ids.length
            ? context.l10n.sharedDeletedCount(deleted, label)
            : context.l10n.sharedDeletedPartial(deleted, ids.length, label),
      );
    } catch (_) {
      if (mounted) _message(context.l10n.sharedDeleteUnconfirmed);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
