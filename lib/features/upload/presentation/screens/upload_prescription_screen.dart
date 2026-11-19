import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/utils/device_app_info.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

class UploadPrescriptionScreen extends ConsumerStatefulWidget {
  const UploadPrescriptionScreen({super.key});

  @override
  ConsumerState<UploadPrescriptionScreen> createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends ConsumerState<UploadPrescriptionScreen> {
  final TextEditingController _manualTextController = TextEditingController();
  String? _selectedFileName;
  String? _uploadedPath;
  bool _isUploading = false;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _manualTextController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _manualTextController.dispose();
    super.dispose();
  }

  void _clearUploadedFile() {
    setState(() {
      _selectedFileName = null;
      _uploadedPath = null;
    });
  }

  String? _formatDisplayDate(dynamic dateVal) {
    if (dateVal == null) return null;
    var str = dateVal.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return null;
    // e.g. "15-Jan-2026 00:00 Hrs" -> "15-Jan-2026"
    str = str.replaceAll(RegExp(r'\s+\d{1,2}:\d{2}(:\d{2})?\s*(hrs|hours)?\.?$', caseSensitive: false), '');

    try {
      final parsed = DateTime.tryParse(str);
      if (parsed != null) {
        return DateFormat('dd-MM-yyyy').format(parsed);
      }

      final slashParts = str.split('/');
      if (slashParts.length == 3) {
        if (slashParts[0].length == 4) {
          return "${slashParts[2].padLeft(2, '0')}-${slashParts[1].padLeft(2, '0')}-${slashParts[0]}";
        }
        return "${slashParts[0].padLeft(2, '0')}-${slashParts[1].padLeft(2, '0')}-${slashParts[2]}";
      }

      final dashParts = str.split('-');
      if (dashParts.length == 3) {
        if (dashParts[0].length == 4) {
          return "${dashParts[2].padLeft(2, '0')}-${dashParts[1].padLeft(2, '0')}-${dashParts[0]}";
        }
        return "${dashParts[0].padLeft(2, '0')}-${dashParts[1].padLeft(2, '0')}-${dashParts[2]}";
      }
    } catch (_) {}

    return str;
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFileName = result.files.single.name;
        _isUploading = true;
      });

      try {
        final formData = FormData.fromMap({'file': await MultipartFile.fromFile(result.files.single.path!)});

        final response = await ApiClient().dio.post('/upload', data: formData);

        if (response.statusCode == 200) {
          _uploadedPath = response.data['fileId'].toString();
          final isImageBased =
              response.data['isImageBased'] == true ||
              _selectedFileName?.toLowerCase().endsWith('.jpg') == true ||
              _selectedFileName?.toLowerCase().endsWith('.jpeg') == true ||
              _selectedFileName?.toLowerCase().endsWith('.png') == true;
          final prefs = SharedPrefs.instance;
          await prefs.setString('prescription_path', _uploadedPath!);
          await prefs.setBool('prescription_is_image_based', isImageBased);

          try {
            final agreementData = await DeviceAppInfo.buildAgreementData();
            await ApiClient().dio.post(
              '/prescriptions',
              data: {
                'hospitalName': '',
                'gridFsFileId': _uploadedPath,
                'originalFileName': _selectedFileName,
                'agreement': agreementData,
              },
            );

            // File card shows the inline success state directly without obscuring action buttons.
          } catch (e) {
            debugPrint("Failed to save prescription record: $e");
            try {
              await ApiClient().dio.delete('/upload/$_uploadedPath');
            } catch (deleteError) {
              debugPrint("Failed to rollback uploaded file: $deleteError");
            }
            if (mounted) {
              showAppSnackBar(
                context,
                'Failed to save prescription record. Please try again.',
                tone: AppTone.danger,
              );
              setState(() {
                _isUploading = false;
                _uploadedPath = null;
                _selectedFileName = null;
              });
            }
            return;
          }
        }
      } on DioException catch (e) {
        if (mounted) {
          String msg;
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            msg = "Unable to connect to the server. Please check your internet connection and try again.";
          } else {
            msg = "Our servers are experiencing issues processing your upload. Please try again later.";
          }
          showAppSnackBar(context, msg, tone: AppTone.danger);
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(
            context,
            'An unexpected error occurred during upload. Please try again later.',
            tone: AppTone.danger,
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  Future<void> _processNext() async {
    final bool hasUploadedFile = _selectedFileName != null && _uploadedPath != null;
    final String manualText = _manualTextController.text.trim();
    final bool hasManualText = manualText.isNotEmpty;

    if (hasUploadedFile && hasManualText) {
      showAppSnackBar(
        context,
        'Please choose only one prescription input method: either upload a prescription PDF or enter your prescription manually.',
        tone: AppTone.warning,
      );
      return;
    }

    if (!hasUploadedFile && !hasManualText) {
      showAppSnackBar(
        context,
        'Please upload a prescription PDF or enter your prescription manually.',
        tone: AppTone.warning,
      );
      return;
    }

    if (_isExtracting) return;

    setState(() {
      _isExtracting = true;
    });

    try {
      if (hasManualText) {
        try {
          final agreementData = await DeviceAppInfo.buildAgreementData();
          final response = await ApiClient().dio.post(
            '/prescriptions',
            data: {
              'hospitalName': '',
              'isManual': true,
              'extractedPrescriptionText': manualText,
              'originalFileName': 'Manual Prescription',
              'agreement': agreementData,
            },
          );

          String? rxId;
          if (response.statusCode == 200 || response.statusCode == 201) {
            if (response.data is Map) {
              rxId =
                  response.data['id']?.toString() ??
                  response.data['data']?['id']?.toString() ??
                  response.data['_id']?.toString();
            }
          }

          final prefs = SharedPrefs.instance;
          await prefs.setString('prescription_path', rxId ?? manualText);
          await prefs.setString('prescription_manual_text', manualText);
          await prefs.setBool('is_manual_prescription', true);
        } catch (e) {
          debugPrint("Failed to save manual prescription record: $e");
          final prefs = SharedPrefs.instance;
          await prefs.setString('prescription_path', manualText);
          await prefs.setString('prescription_manual_text', manualText);
          await prefs.setBool('is_manual_prescription', true);
        }
      } else {
        final prefs = SharedPrefs.instance;
        await prefs.setBool('is_manual_prescription', false);
        await prefs.remove('prescription_manual_text');
      }

      List<dynamic> policiesList = [];
      bool hasPolicies = false;

      try {
        final response = await ApiClient().dio.get('/policies/summary');
        if (response.statusCode == 200) {
          if (response.data is Map && response.data['policies'] is List) {
            policiesList = response.data['policies'];
            hasPolicies = policiesList.isNotEmpty;
          } else if (response.data is List) {
            policiesList = response.data;
            hasPolicies = policiesList.isNotEmpty;
          }
        }
      } catch (e) {
        debugPrint("Failed to fetch policies: $e");
      }

      if (!mounted) return;

      setState(() {
        _isExtracting = false;
      });

      if (!hasPolicies) {
        context.push('/upload-policy');
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          final p = dialogContext.palette;
          return AlertDialog(
            icon: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
              child: Icon(Icons.policy_outlined, color: p.primary),
            ),
            title: const Text("Existing Policy Found", textAlign: TextAlign.center),
            content: const Text(
              "We found existing policies in your account. Would you like to analyze this prescription using one of your saved policies?",
              textAlign: TextAlign.center,
            ),
            actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showPolicySelectionDialog(policiesList);
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text("Continue Existing Policy"),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.push('/upload-policy');
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text("Upload New Policy"),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } catch (err) {
      debugPrint("Error in _processNext: $err");
      if (mounted) {
        showAppSnackBar(context, friendlyErrorMessage(err), tone: AppTone.danger);
      }
    } finally {
      if (mounted && _isExtracting) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  void _showPolicySelectionDialog(List<dynamic> policies) {
    // Multiple policies may be selected: the prescription is analysed against
    // each one independently.
    final Set<String> localSelectedPolicyIds = {};

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final pal = dialogCtx.palette;
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              contentPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select Policies"),
                  const SizedBox(height: 4),
                  Text(
                    localSelectedPolicyIds.isEmpty
                        ? "Choose one or more policies to compare"
                        : "${localSelectedPolicyIds.length} selected",
                    style: dialogCtx.text.bodySmall?.copyWith(
                      color: localSelectedPolicyIds.isEmpty ? pal.textTertiary : pal.primary,
                      fontWeight: localSelectedPolicyIds.isEmpty ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: policies.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final p = policies[index];
                    final isSelected = localSelectedPolicyIds.contains(p['id']);

                    final String provider = p['providerName'] ?? 'Insurance Policy';
                    final String policyType = p['policyType'] ?? '';
                    final String? holderName = p['policyHolderName'];
                    final String? formattedStart = _formatDisplayDate(p['startDate']);
                    final String? formattedEnd = _formatDisplayDate(p['endDate'] ?? p['expiryDate']);
                    final String policyNo = p['displayId'] ?? p['policyNumber'] ?? 'Unknown';
                    final String? fileName = p['originalFileName'];

                    ({String label, String value})? validity;
                    if (formattedStart != null && formattedEnd != null) {
                      validity = (label: 'Validity', value: '$formattedStart to $formattedEnd');
                    } else if (formattedStart != null) {
                      validity = (label: 'Start Date', value: formattedStart);
                    } else if (formattedEnd != null) {
                      validity = (label: 'Expiry', value: formattedEnd);
                    }

                    return Material(
                      color: isSelected ? pal.primarySoft : pal.surface,
                      borderRadius: AppRadius.mdAll,
                      child: InkWell(
                        onTap: () {
                          setDialogState(() {
                            final id = p['id']?.toString();
                            if (id == null) return;
                            if (localSelectedPolicyIds.contains(id)) {
                              localSelectedPolicyIds.remove(id);
                            } else {
                              localSelectedPolicyIds.add(id);
                            }
                          });
                        },
                        borderRadius: AppRadius.mdAll,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.mdAll,
                            border: Border.all(
                              color: isSelected ? pal.primary : pal.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                color: isSelected ? pal.primary : pal.borderStrong,
                                size: 22,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(provider, style: dialogCtx.text.titleSmall?.copyWith(height: 1.35)),
                                    if (policyType.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(policyType, style: dialogCtx.text.bodySmall),
                                    ],
                                    const SizedBox(height: AppSpacing.xs),
                                    Divider(height: 1, color: pal.border),
                                    const SizedBox(height: AppSpacing.xxs),
                                    if (holderName != null && holderName.isNotEmpty)
                                      _PolicyMetaLine(label: 'Holder', value: holderName),
                                    _PolicyMetaLine(label: 'Policy No', value: policyNo),
                                    if (validity != null) _PolicyMetaLine(label: validity.label, value: validity.value),
                                    if (fileName != null && fileName.isNotEmpty)
                                      _PolicyMetaLine(label: 'File', value: fileName, ellipsize: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: localSelectedPolicyIds.isEmpty
                          ? null
                          : () async {
                              Navigator.of(dialogContext).pop();
                              final prefs = SharedPrefs.instance;
                              final selected = localSelectedPolicyIds.toList();
                              await prefs.remove('policy_path'); // Ensure policy_path is cleared

                              if (selected.length == 1) {
                                // Unchanged single-policy flow
                                await prefs.setString('policy_id', selected.first);
                                await prefs.remove('policy_ids');
                                if (mounted) context.push('/analysis');
                              } else {
                                await prefs.setString('policy_ids', jsonEncode(selected));
                                await prefs.remove('policy_id');
                                if (mounted) context.push('/analysis-multi');
                              }
                            },
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                      child: Text(
                        localSelectedPolicyIds.length > 1
                            ? "Analyze With ${localSelectedPolicyIds.length} Policies"
                            : "Analyze With Selected Policy",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: const Text("Cancel"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool hasFile = _selectedFileName != null && _uploadedPath != null;
    final bool hasManual = _manualTextController.text.trim().isNotEmpty;
    final bool isValid = (hasFile ^ hasManual);
    final bool canSubmit = isValid && !_isUploading && !_isExtracting;
    final bool bothMethods = _selectedFileName != null && hasManual;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Add Prescription'),
      ),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepHeader(current: 2, total: 3, label: 'Prescription'),
                const SizedBox(height: AppSpacing.xl),
                Text('Add your prescription', style: context.text.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text("Upload your doctor's prescription, diagnosis, or medical bills.", style: context.text.bodyMedium),
                const SizedBox(height: AppSpacing.xl),

                // Option 1: upload a document
                _OptionLabel(index: 1, title: 'Upload a document'),
                const SizedBox(height: AppSpacing.sm),
                if (_selectedFileName == null || _isUploading)
                  _UploadDropZone(
                    title: _isUploading
                        ? 'Uploading ${_selectedFileName ?? 'document'}…'
                        : 'Tap to upload medical documents',
                    subtitle: _isUploading ? 'Please keep the app open' : 'PDF, JPG, PNG or DOCX',
                    icon: Icons.find_in_page_outlined,
                    loading: _isUploading,
                    onTap: _isUploading ? null : _pickAndUploadFile,
                  )
                else
                  _SelectedFileCard(
                    fileName: _selectedFileName!,
                    status: 'File uploaded successfully',
                    onRemove: _clearUploadedFile,
                    onReplace: _pickAndUploadFile,
                  ),

                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(child: Divider(color: p.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Text('OR', style: context.text.labelSmall),
                    ),
                    Expanded(child: Divider(color: p.border)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Option 2: describe it manually
                _OptionLabel(index: 2, title: 'Enter your prescription manually'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  borderColor: bothMethods ? p.warning.border : (hasManual ? p.primary.withAlpha(160) : null),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconTile(icon: Icons.edit_note_rounded, size: 32),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text('Prescription / Diagnosis Details', style: context.text.titleSmall)),
                          if (hasManual)
                            TextButton.icon(
                              onPressed: () {
                                _manualTextController.clear();
                                setState(() {});
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: p.danger.fg,
                                minimumSize: const Size(44, 40),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Clear'),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _manualTextController,
                        minLines: 4,
                        maxLines: 8,
                        onChanged: (val) => setState(() {}),
                        style: context.text.bodyLarge?.copyWith(fontSize: 14),
                        decoration: InputDecoration(
                          fillColor: p.surfaceMuted,
                          hintText: "Describe your diagnosis, symptoms, doctor's findings, or prescribed treatment...",
                          hintMaxLines: 3,
                        ),
                      ),
                      // Only one input method can be used at a time.
                      if (bothMethods) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
                          decoration: BoxDecoration(color: p.warning.bg, borderRadius: AppRadius.smAll),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(Icons.info_outline_rounded, size: 16, color: p.warning.fg),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Please choose only one prescription input method: either upload a prescription PDF or enter your prescription manually.',
                                  textAlign: TextAlign.start,
                                  style: context.text.bodySmall?.copyWith(color: p.textPrimary, height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          FilledButton(
            onPressed: canSubmit ? _processNext : null,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isExtracting) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: p.onPrimary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Processing...'),
                ] else ...[
                  Flexible(
                    child: Text(
                      hasManual ? 'Process Manual Prescription' : 'Process Prescription',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aligned "Label   Value" line used in the policy selection list.
class _PolicyMetaLine extends StatelessWidget {
  final String label;
  final String value;
  final bool ellipsize;

  const _PolicyMetaLine({required this.label, required this.value, this.ellipsize = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: context.text.bodySmall?.copyWith(color: p.textTertiary)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: ellipsize ? 1 : null,
              overflow: ellipsize ? TextOverflow.ellipsis : null,
              style: context.text.bodySmall?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered label introducing one of the input options.
class _OptionLabel extends StatelessWidget {
  final int index;
  final String title;

  const _OptionLabel({required this.index, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
          child: Text(
            '$index',
            style: context.text.labelSmall?.copyWith(color: p.primary, fontWeight: FontWeight.w700, letterSpacing: 0),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(title, style: context.text.titleSmall)),
      ],
    );
  }
}

/// Dashed upload target.
class _UploadDropZone extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _UploadDropZone({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: p.surface,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgAll,
          child: CustomPaint(
            painter: DashedBorderPainter(color: p.borderStrong, strokeWidth: 1.5, gap: 6, radius: AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6))
                        : Icon(icon, size: 28, color: p.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle, textAlign: TextAlign.center, style: context.text.bodySmall),
                  if (loading) ...[
                    const SizedBox(height: AppSpacing.md),
                    const ClipRRect(borderRadius: AppRadius.pillAll, child: LinearProgressIndicator(minHeight: 4)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card shown once a document has been uploaded.
class _SelectedFileCard extends StatelessWidget {
  final String fileName;
  final String status;
  final VoidCallback onRemove;
  final VoidCallback? onReplace;

  const _SelectedFileCard({required this.fileName, required this.status, required this.onRemove, this.onReplace});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lower = fileName.toLowerCase();
    final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
    return AppCard(
      borderColor: p.success.border,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          IconTile(icon: isImage ? Icons.image_outlined : Icons.description_outlined, size: 44),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: p.success.fg),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        status,
                        style: context.text.bodySmall?.copyWith(color: p.success.fg, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onReplace != null)
            IconButton(
              onPressed: onReplace,
              tooltip: 'Replace file',
              icon: Icon(Icons.swap_horiz_rounded, color: p.textSecondary),
            ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove file',
            icon: Icon(Icons.delete_outline_rounded, color: p.danger.fg),
          ),
        ],
      ),
    );
  }
}

/// Visual-only progress indicator for the Consent → Prescription → Policy flow.
class _StepHeader extends StatelessWidget {
  final int current;
  final int total;
  final String label;

  const _StepHeader({required this.current, required this.total, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'STEP $current OF $total',
              style: context.text.labelSmall?.copyWith(color: p.primary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                '· $label',
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: p.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (int i = 1; i <= total; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current ? p.primary : p.border,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// Custom Painter for Dashed Border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedBorderPainter({required this.color, this.strokeWidth = 2.0, this.gap = 5.0, this.radius = 16.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));

    final Path dashedPath = Path();
    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        final double len = gap; // length of dash
        dashedPath.addPath(measurePath.extractPath(distance, distance + len), Offset.zero);
        distance += len + gap; // jump by length + gap
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
