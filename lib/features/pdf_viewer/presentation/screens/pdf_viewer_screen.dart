import 'package:claimsupport/core/localization/localization.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:xml/xml.dart';

const _wordDocument = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.fileId, required this.title});

  final String fileId;
  final String title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _cancelToken = CancelToken();
  Uint8List? _bytes;
  String? _wordText;
  bool _isImage = false;
  bool _isLoading = true;
  Object? _error;
  bool _isInvalid = false;

  String get _invalidDocument {
    if (widget.title.startsWith('PSCT')) return context.l10n.sharedInvalidPrescription;
    if (widget.title.startsWith('PCY')) return context.l10n.sharedInvalidPolicy;
    return context.l10n.sharedInvalidDocument;
  }

  @override
  void initState() {
    super.initState();
    _fetchDocument();
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _fetchDocument() async {
    try {
      final response = await ApiClient().dio.get<List<int>>(
        '/upload/${Uri.encodeComponent(widget.fileId)}',
        options: Options(responseType: ResponseType.bytes),
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      final data = response.data;
      if (data == null || data.length < 10) {
        _fail(invalid: true);
        return;
      }

      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      final mimeType = response.headers.value(Headers.contentTypeHeader)?.split(';').first.trim().toLowerCase();
      final wordText = mimeType == _wordDocument ? await compute(_readWordText, bytes) : null;
      if (!mounted) return;
      setState(() {
        _bytes = wordText == null ? bytes : null;
        _wordText = wordText;
        _isImage = mimeType?.startsWith('image/') ?? false;
        _isLoading = false;
      });
    } on FormatException {
      _fail(invalid: true);
    } catch (error) {
      _fail(error: error, invalid: error is DioException && error.response?.statusCode == 404);
    }
  }

  void _fail({Object? error, bool invalid = false}) {
    if (!mounted) return;
    setState(() {
      _error = error;
      _isInvalid = invalid;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), tooltip: context.l10n.sharedBack, onPressed: () => context.pop()),
    ),
    body: _buildDocument(),
  );

  Widget _buildDocument() {
    if (_isLoading) return LoadingState(message: context.l10n.sharedLoadingDocument);
    if (_error != null || _isInvalid) {
      final isInvalid = _isInvalid;
      return EmptyState(
        icon: isInvalid ? Icons.insert_drive_file_outlined : Icons.cloud_off_rounded,
        title: isInvalid ? _invalidDocument : context.l10n.sharedLoadingFileFailed,
        message: isInvalid ? context.l10n.sharedUnreadableDocument : friendlyErrorMessage(_error, l10n: context.l10n),
        action: isInvalid
            ? null
            : OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _fetchDocument();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.l10n.sharedTryAgain),
              ),
      );
    }
    if (_wordText case final text?) {
      return SingleChildScrollView(padding: const EdgeInsets.all(20), child: SelectableText(text));
    }
    if (_isImage) {
      return InteractiveViewer(
        maxScale: 5,
        child: SizedBox.expand(
          child: Image.memory(
            _bytes!,
            fit: BoxFit.contain,
            semanticLabel: widget.title,
            errorBuilder: (_, _, _) =>
                EmptyState(icon: Icons.broken_image_outlined, title: context.l10n.sharedImageOpenFailed),
          ),
        ),
      );
    }
    return SfPdfViewer.memory(
      _bytes!,
      canShowScrollHead: false,
      canShowScrollStatus: true,
      onDocumentLoadFailed: (_) => Future.microtask(() => _fail(invalid: true)),
    );
  }
}

String _readWordText(Uint8List bytes) {
  final file = ZipDecoder().decodeBytes(bytes).find('word/document.xml');
  const maxXmlBytes = 32 * 1024 * 1024;
  if (file == null || file.size > maxXmlBytes) throw const FormatException('Unreadable Word document');

  final xml = XmlDocument.parse(utf8.decode(file.content));
  const namespace = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  final paragraphs = xml
      .findAllElements('p', namespaceUri: namespace)
      .map((element) => element.findAllElements('t', namespaceUri: namespace).map((run) => run.innerText).join())
      .where((text) => text.trim().isNotEmpty);
  final text = paragraphs.join('\n\n');
  if (text.isEmpty) throw const FormatException('No readable text in Word document');
  return text;
}
