import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_choices.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/features/documents/presentation/document_summary.dart';
import 'package:claimsupport/features/documents/presentation/saved_list_actions.dart';
import 'package:claimsupport/features/documents/presentation/saved_list_feedback.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SavedDocumentList<T> extends StatefulWidget {
  const SavedDocumentList({
    super.key,
    required this.title,
    required this.singular,
    required this.page,
    required this.isLoading,
    required this.error,
    required this.describe,
    required this.createdAt,
    required this.idOf,
    required this.onOpen,
    required this.onRefresh,
    required this.fetchPage,
    required this.onDelete,
    this.onAdd,
    this.filters = const {},
    this.fetchFilterPage,
  });

  final VoidCallback? onAdd;
  final Map<String, bool Function(T)> filters;
  final Future<PaginationResponse<T>> Function(int)? fetchFilterPage;
  final String title;
  final String singular;
  final PaginationResponse<T>? page;
  final bool isLoading;
  final Object? error;
  final DocumentSummary Function(T) describe;
  final DateTime? Function(T) createdAt;
  final String Function(T) idOf;
  final void Function(BuildContext, T, DocumentSummary) onOpen;
  final Future<void> Function() onRefresh;
  final Future<PaginationResponse<T>> Function(int) fetchPage;
  final Future<int> Function(List<String>) onDelete;

  @override
  State<SavedDocumentList<T>> createState() => _SavedDocumentListState<T>();
}

class _SavedDocumentListState<T> extends State<SavedDocumentList<T>> with SavedListActions<SavedDocumentList<T>, T> {
  String _filter = 'All';
  PaginationResponse<T>? _filterSource;
  Future<PaginationResponse<T>>? _allPages;

  Future<void> _refresh() async {
    if (listBusy) return;
    setState(() {
      resetList();
      _filterSource = null;
    });
    await widget.onRefresh();
  }

  Future<PaginationResponse<T>> _loadAll(PaginationResponse<T> page) async {
    final fetch = widget.fetchFilterPage ?? widget.fetchPage;
    while (page.hasNextPage && page.docs.isNotEmpty) {
      page = page.append(await fetch(page.page + 1));
    }
    return page;
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.page;
    final matches = widget.filters[_filter];
    if (source == null || matches == null) return _list(source, loading: widget.isLoading, error: widget.error);

    if (!identical(_filterSource, source)) {
      _filterSource = source;
      _allPages = _loadAll(source);
    }
    return FutureBuilder(
      future: _allPages,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final records = (snapshot.data ?? source).docs.where(matches).toList();
        final filtered = loading
            ? null
            : PaginationResponse<T>(
                docs: records,
                totalDocs: records.length,
                limit: source.limit,
                totalPages: records.isEmpty ? 0 : 1,
                page: 1,
                hasPrevPage: false,
                hasNextPage: false,
              );
        return _list(filtered, loading: loading, error: snapshot.error ?? widget.error);
      },
    );
  }

  Widget _list(PaginationResponse<T>? source, {required bool loading, required Object? error}) {
    final context = this.context;
    final page = source == null ? null : visiblePage(source);
    final records = page?.docs.toList() ?? <T>[];
    final earliest = DateTime.fromMillisecondsSinceEpoch(0);
    records.sort((a, b) => (widget.createdAt(b) ?? earliest).compareTo(widget.createdAt(a) ?? earliest));
    final title = widget.title;
    final lowerTitle = title.toLowerCase();
    return PushedShell(
      title: title,
      subtitle: page == null ? null : context.l10n.sharedSavedCount(page.totalDocs),
      action: widget.onAdd == null
          ? null
          : AppIconButton(icon: AppIcons.plus, label: context.l10n.sharedAddPrescription, onPressed: widget.onAdd),
      showTitleInSelection: true,
      selectionHeader: selecting ? selectionHeader(source, widget.fetchPage, widget.idOf) : null,
      bottom: selecting
          ? selectionFooter(
              singular: widget.singular == 'policy' ? context.l10n.sharedPolicy.toLowerCase() : context.l10n.sharedPrescription.toLowerCase(),
              plural: lowerTitle,
              isDocument: true,
              delete: (ids) async {
                final deleted = await widget.onDelete(ids);
                if (mounted && _filter != 'All') {
                  _filterSource = null;
                  await widget.onRefresh();
                }
                return deleted;
              },
            )
          : null,
      onBack: () => context.canPop() ? context.pop() : context.go('/dashboard'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.filters.isNotEmpty && !selecting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.screenPadding, vertical: DsSpace.s8),
              child: AppFilterChipRow<String>(
                options: {'All': context.l10n.sharedAll, for (final name in widget.filters.keys) name: _filterLabel(name)},
                selected: _filter,
                onChanged: listBusy
                    ? null
                    : (filter) {
                        if (filter != _filter) setState(() => _filter = filter);
                      },
              ),
            ),
          Expanded(
            child: loadOnScroll(
              source: source,
              fetch: widget.fetchPage,
              enabled: !loading && error == null,
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  key: ValueKey(_filter),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    DsSpace.screenPadding,
                    DsSpace.s8,
                    DsSpace.screenPadding,
                    DsSpace.s32,
                  ),
                  children: [
                    if (error != null && !loading)
                      SavedListError(
                        error: error,
                        offlineMessage: page == null ? context.l10n.sharedOffline : context.l10n.sharedOfflineShowSaved(lowerTitle),
                        message: context.l10n.sharedCouldNotLoadItems(lowerTitle),
                        onRetry: _refresh,
                      ),
                    if (page == null && loading) const SavedListSkeleton(),
                    if (page != null && source != null) ...[
                      if (records.isEmpty)
                        SavedListMessage(
                          _filter == 'All'
                              ? context.l10n.sharedDocumentsShownHere(title)
                              : context.l10n.sharedNoFilteredDocuments(_filterLabel(_filter).toLowerCase(), lowerTitle),
                        ),
                      if (records.isNotEmpty) ...[
                        AppRowGroup(rows: [for (final record in records) _row(context, record)]),
                        const SizedBox(height: DsSpace.s12),
                        Text(
                          widget.singular == 'policy'
                              ? context.l10n.sharedAddPolicyWithCheck
                              : context.l10n.sharedLongPressDelete,
                          style: AppTextStyles.captionRegular.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                      moreStatus(source, widget.fetchPage),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(String key) => switch (key) {
    'Uploaded' => context.l10n.sharedUploaded,
    'Manual' => context.l10n.sharedManual,
    _ => key,
  };

  Widget _row(BuildContext context, T record) {
    final summary = widget.describe(record);
    final id = widget.idOf(record);
    return AppDocumentRow(
      type: summary.type,
      title: summary.title,
      meta: summary.meta,
      timestamp: summary.timestamp,
      state: summary.state,
      checkbox: true,
      grouped: true,
      selected: itemSelection(id),
      onLongPress: selecting || id.isEmpty ? null : () => beginSelection(id),
      onTap: selecting && id.isNotEmpty ? () => toggleItem(id) : () => widget.onOpen(context, record, summary),
    );
  }
}
