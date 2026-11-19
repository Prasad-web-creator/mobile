import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String title;

  const PdfViewerScreen({super.key, required this.fileId, required this.title});

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    try {
      final response = await ApiClient().dio.get<List<int>>(
        '/upload/${widget.fileId}',
        options: Options(responseType: ResponseType.bytes),
      );

      final rawData = response.data;
      if (rawData != null) {
        // Cast directly if Dio already returned a Uint8List (avoids a full copy).
        // Fall back to Uint8List.fromList() only when the underlying type differs.
        final bytes = rawData is Uint8List ? rawData : Uint8List.fromList(rawData);

        if (bytes.isEmpty || bytes.length < 10) {
          String msg = 'Invalid document';
          if (widget.title.startsWith('PSCT')) {
            msg = 'Invalid prescription Uploaded';
          } else if (widget.title.startsWith('PCY')) {
            msg = 'Invalid policy Uploaded';
          }
          setState(() {
            _error = msg;
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Received empty document.';
          _isLoading = false;
        });
      }
    } catch (e) {
      String msg = "Couldn't load the document. ${friendlyErrorMessage(e)}";
      if (e is DioException && e.response?.statusCode == 404) {
        msg = 'Invalid document';
        if (widget.title.startsWith('PSCT')) {
          msg = 'Invalid prescription Uploaded';
        } else if (widget.title.startsWith('PCY')) {
          msg = 'Invalid policy Uploaded';
        }
      }
      setState(() {
        _error = msg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInvalid = _error != null && _error!.startsWith('Invalid');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const LoadingState(message: 'Loading document…')
          : _error != null
          ? EmptyState(
              icon: isInvalid ? Icons.insert_drive_file_outlined : Icons.cloud_off_rounded,
              title: _error!,
              message: isInvalid
                  ? 'This file could not be opened as a document. Please upload a clear PDF or image.'
                  : null,
              action: isInvalid
                  ? null
                  : OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _fetchPdf();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try again'),
                    ),
            )
          : SfPdfViewer.memory(
              _pdfBytes!,
              canShowScrollHead: false,
              canShowScrollStatus: true,
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                String msg = 'Invalid document';
                if (widget.title.startsWith('PSCT')) {
                  msg = 'Invalid prescription Uploaded';
                } else if (widget.title.startsWith('PCY')) {
                  msg = 'Invalid policy Uploaded';
                }
                Future.microtask(() {
                  if (mounted) {
                    setState(() {
                      _error = msg;
                    });
                  }
                });
              },
            ),
    );
  }
}
