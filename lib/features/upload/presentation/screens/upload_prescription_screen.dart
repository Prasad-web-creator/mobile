import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/localization/translation_mapper.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';
import 'package:claimsupport/core/config/app_config_provider.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/utils/device_app_info.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

class UploadPrescriptionScreen extends ConsumerStatefulWidget {
  const UploadPrescriptionScreen({super.key, this.resumeDraft = false});

  final bool resumeDraft;

  @override
  ConsumerState<UploadPrescriptionScreen> createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends ConsumerState<UploadPrescriptionScreen> {
  final TextEditingController _manualTextController = TextEditingController();
  String? _selectedFileName;
  String? _uploadedPath;
  String? _prescriptionRecordId;
  bool _isUploading = false;
  bool _isExtracting = false;
  String? _savedManualText;
  String? _savedManualId;
  CancelToken? _extractionToken;
  AppRuntimeConfig get _config => ref.read(appConfigProvider).value ?? AppRuntimeConfig.defaults;

  @override
  void initState() {
    super.initState();
    final savedId = widget.resumeDraft ? SharedPrefs.instance.getString('prescription_path') : null;
    if (savedId != null) {
      _prescriptionRecordId = savedId;
      _uploadedPath = savedId;
      _selectedFileName = '';
    }
    _manualTextController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _extractionToken?.cancel();
    _manualTextController.dispose();
    super.dispose();
  }

  void _clearUploadedFile() {
    SharedPrefs.instance.remove('prescription_path');
    setState(() {
      _selectedFileName = null;
      _uploadedPath = null;
      _prescriptionRecordId = null;
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
        return formatLocalizedDate(context.l10n, parsed, pattern: 'dd-MM-yyyy');
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
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (!mounted) return;
    final file = result?.files.single;
    if (file != null && file.path != null) {
      if (!_config.acceptsFileSize(file.size)) {
        showAppSnackBar(context, context.l10n.sharedFileLimit(_config.maxFileSizeMb), tone: AppTone.warning);
        return;
      }
      setState(() => _isUploading = true);
      String? uploadedId;

      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path!),
          'documentType': 'prescription',
        });

        final response = await ApiClient().dio.post('/upload', data: formData, options: analysisUploadOptions());
        uploadedId = response.data['fileId'] as String?;
        if (uploadedId == null) throw StateError('Upload returned no document ID');
        final agreementData = await DeviceAppInfo.buildAgreementData();
        final saved = await ApiClient().dio.post(
          '/prescriptions',
          options: analysisUploadOptions(),
          data: {
            'hospitalName': '',
            'gridFsFileId': uploadedId,
            'originalFileName': file.name,
            'agreement': agreementData,
          },
        );
        final recordId = (saved.data['_id'] ?? saved.data['id'])?.toString();
        if (recordId == null) throw StateError('No prescription record returned');
        await SharedPrefs.instance.setString('prescription_path', recordId);
        await SharedPrefs.instance.setBool('prescription_is_image_based', response.data['isImageBased'] == true);
        if (!mounted) return;
        setState(() {
          _uploadedPath = uploadedId;
          _prescriptionRecordId = recordId;
          _selectedFileName = file.name;
        });
      } on DioException catch (e) {
        await _rollbackUpload(uploadedId);
        if (mounted) {
          String msg;
          if (e.response?.statusCode == 413) {
            msg = _apiMessage(e, context.l10n.sharedFileLimit(_config.maxFileSizeMb));
          } else if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            msg = friendlyErrorMessage(e, l10n: context.l10n);
          } else {
            msg = context.l10n.sharedUploadServerError;
          }
          showAppSnackBar(context, msg, tone: AppTone.danger);
        }
      } catch (_) {
        await _rollbackUpload(uploadedId);
        if (mounted) {
          showAppSnackBar(
            context,
            context.l10n.sharedUploadUnexpected,
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

  String _apiMessage(DioException error, String fallback) {
    final data = error.response?.data;
    final message = data is Map ? data['message'] ?? data['detail'] : null;
    return message is String && context.l10n.localeName == 'en' ? message : fallback;
  }

  Future<void> _rollbackUpload(String? fileId) async {
    if (fileId == null) return;
    try {
      await ApiClient().dio.delete('/upload/$fileId');
    } on DioException {
      // An unlinked upload is eligible for server cleanup.
    }
  }

  Future<void> _processNext() async {
    final bool hasUploadedFile = _selectedFileName != null && _uploadedPath != null;
    final String manualText = _manualTextController.text.trim();
    final bool hasManualText = manualText.isNotEmpty;

    if (hasUploadedFile && hasManualText) {
      showAppSnackBar(
        context,
        context.l10n.sharedChooseOnePrescriptionMethod,
        tone: AppTone.warning,
      );
      return;
    }

    if (!hasUploadedFile && !hasManualText) {
      showAppSnackBar(
        context,
        context.l10n.sharedProvidePrescription,
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
          if (_savedManualText != manualText || _savedManualId == null) {
            final agreementData = await DeviceAppInfo.buildAgreementData();
            final response = await ApiClient().dio.post(
              '/prescriptions',
              options: analysisUploadOptions(),
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

            if (rxId == null) throw StateError('No prescription record returned');
            _savedManualText = manualText;
            _savedManualId = rxId;
          }
          final prefs = SharedPrefs.instance;
          await prefs.setString('prescription_path', _savedManualId!);
          await prefs.remove('prescription_manual_text');
          await prefs.setBool('is_manual_prescription', true);
        } on DioException catch (error) {
          if (mounted) {
            showAppSnackBar(
              context,
              _apiMessage(error, context.l10n.sharedCouldNotSavePrescription),
              tone: AppTone.warning,
            );
          }
          return;
        }
      } else {
        final recordId = _prescriptionRecordId;
        final prefs = SharedPrefs.instance;
        await prefs.setString('prescription_path', recordId ?? _uploadedPath!);
        await prefs.setBool('is_manual_prescription', false);
        await prefs.remove('prescription_manual_text');
      }

      final prefs = SharedPrefs.instance;
      final jobId = prefs.getString(analysisDraftKey);
      final prescriptionId = prefs.getString('prescription_path');
      if (jobId != null && prescriptionId != null && mounted) {
        final token = _extractionToken = CancelToken();
        await AnalysisRepository().preparePrescription(jobId, prescriptionId, token);
      }
      if (!mounted) return;
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
        debugPrint('Failed to fetch policies.');
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
            title: Text(context.l10n.sharedExistingPolicyFound, textAlign: TextAlign.center),
            content: Text(
              context.l10n.sharedUseSavedPolicy,
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
                    child: Text(context.l10n.sharedContinueExistingPolicy),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.push('/upload-policy');
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: Text(context.l10n.sharedUploadNewPolicy),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } catch (err) {
      debugPrint('Could not proceed from prescription upload.');
      if (mounted) {
        showAppSnackBar(context, friendlyErrorMessage(err, l10n: context.l10n), tone: AppTone.danger);
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
    final config = _config;

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
                  Text(context.l10n.sharedSelectPolicies),
                  const SizedBox(height: 4),
                  Text(
                    localSelectedPolicyIds.isEmpty
                        ? context.l10n.sharedPickUpToPolicies(config.maxPolicies)
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

                    final String provider = p['providerName'] ?? context.l10n.sharedInsurancePolicy;
                    final policyType = localizedPolicyType(context.l10n, p['policyType']?.toString() ?? '');
                    final String? holderName = p['policyHolderName'];
                    final String? formattedStart = _formatDisplayDate(p['startDate']);
                    final String? formattedEnd = _formatDisplayDate(p['endDate'] ?? p['expiryDate']);
                    final String policyNo = p['displayId'] ?? p['policyNumber'] ?? context.l10n.sharedUnknown;
                    final String? fileName = p['originalFileName'];

                    ({String label, String value})? validity;
                    if (formattedStart != null && formattedEnd != null) {
                      validity = (label: context.l10n.sharedValidity, value: context.l10n.sharedDateRange(formattedStart, formattedEnd));
                    } else if (formattedStart != null) {
                      validity = (label: context.l10n.sharedStartDateTitle, value: formattedStart);
                    } else if (formattedEnd != null) {
                      validity = (label: context.l10n.sharedExpiry, value: formattedEnd);
                    }

                    return Material(
                      color: isSelected ? pal.primarySoft : pal.surface,
                      borderRadius: AppRadius.mdAll,
                      child: InkWell(
                        onTap: () {
                          final id = p['id']?.toString();
                          if (id == null) return;
                          if (!localSelectedPolicyIds.contains(id) &&
                              localSelectedPolicyIds.length >= config.maxPolicies) {
                            showAppSnackBar(context, config.policyLimitMessage, tone: AppTone.warning);
                            return;
                          }
                          setDialogState(() {
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
                                      _PolicyMetaLine(label: context.l10n.sharedHolder, value: holderName),
                                    _PolicyMetaLine(label: context.l10n.sharedPolicyNo, value: policyNo),
                                    if (validity != null) _PolicyMetaLine(label: validity.label, value: validity.value),
                                    if (fileName != null && fileName.isNotEmpty)
                                      _PolicyMetaLine(label: context.l10n.sharedFile, value: fileName, ellipsize: true),
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

                              await prefs.setString('policy_ids', jsonEncode(selected));
                              await prefs.remove('policy_id');
                              if (mounted) context.push('/analysis-multi');
                            },
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                      child: Text(
                        localSelectedPolicyIds.length > 1
                            ? context.l10n.sharedAnalyzeWithPolicies(localSelectedPolicyIds.length)
                            : context.l10n.sharedAnalyzeWithSelectedPolicy,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: Text(context.l10n.sharedCancel),
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
    final config = ref.watch(appConfigProvider).value ?? AppRuntimeConfig.defaults;
    final p = context.palette;
    final bool hasFile = _selectedFileName != null && _uploadedPath != null;
    final bool hasManual = _manualTextController.text.trim().isNotEmpty;
    final bool isValid = (hasFile ^ hasManual);
    final bool canSubmit = isValid && !_isUploading && !_isExtracting;
    final bool bothMethods = _selectedFileName != null && hasManual;

    return FlowShell(
      title: context.l10n.sharedAddPrescriptionTitle,
      step: 2,
      stepCount: 3,
      onClose: () => context.go('/dashboard'),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.sharedAddYourPrescription, style: context.text.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(context.l10n.sharedUploadDoctorDocument, style: context.text.bodyMedium),
                const SizedBox(height: AppSpacing.xl),

                // Option 1: upload a document
                _OptionLabel(index: 1, title: context.l10n.sharedUploadDocument),
                const SizedBox(height: AppSpacing.sm),
                if (_selectedFileName == null || _isUploading)
                  _UploadDropZone(
                    title: _isUploading
                        ? context.l10n.sharedUploadNamed(_selectedFileName?.isEmpty == true ? context.l10n.sharedSavedPrescription : (_selectedFileName ?? context.l10n.sharedDocument))
                        : context.l10n.sharedUploadMedicalDocuments,
                    subtitle: _isUploading
                        ? context.l10n.sharedKeepAppOpen
                        : context.l10n.sharedPdfImageLimit(config.maxFileSizeMb),
                    icon: Icons.find_in_page_outlined,
                    loading: _isUploading,
                    onTap: _isUploading ? null : _pickAndUploadFile,
                  )
                else
                  _SelectedFileCard(
                    fileName: _selectedFileName!.isEmpty ? context.l10n.sharedSavedPrescription : _selectedFileName!,
                    status: context.l10n.sharedUploadSucceeded,
                    onRemove: _clearUploadedFile,
                    onReplace: _pickAndUploadFile,
                  ),

                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(child: Divider(color: p.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Text(context.l10n.sharedOr, style: context.text.labelSmall),
                    ),
                    Expanded(child: Divider(color: p.border)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Option 2: describe it manually
                _OptionLabel(index: 2, title: context.l10n.sharedManualPrescription),
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
                          Expanded(child: Text(context.l10n.sharedPrescriptionDetails, style: context.text.titleSmall)),
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
                              label: Text(context.l10n.sharedClear),
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
                          hintText: context.l10n.sharedDescribeSymptoms,
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
                                  context.l10n.sharedChooseOnePrescriptionMethod,
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
      bottomAction: AppButton(
        label: _isExtracting
            ? context.l10n.sharedReadingPrescription
            : hasManual
            ? context.l10n.sharedProcessManualPrescription
            : context.l10n.sharedProcessPrescription,
        onPressed: canSubmit ? _processNext : null,
        busy: _isExtracting,
        icon: AppIcons.caretRight,
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
              tooltip: context.l10n.sharedReplaceFile,
              icon: Icon(Icons.swap_horiz_rounded, color: p.textSecondary),
            ),
          IconButton(
            onPressed: onRemove,
            tooltip: context.l10n.sharedRemoveFile,
            icon: Icon(Icons.delete_outline_rounded, color: p.danger.fg),
          ),
        ],
      ),
    );
  }
}

/// Visual-only progress indicator for the Consent → Prescription → Policy flow.
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
