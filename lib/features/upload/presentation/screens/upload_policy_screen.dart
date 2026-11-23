import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/utils/device_app_info.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

class UploadPolicyScreen extends StatefulWidget {
  const UploadPolicyScreen({super.key});

  @override
  State<UploadPolicyScreen> createState() => _UploadPolicyScreenState();
}

/// One policy the user has uploaded in this session, with its own continuity answers.
///
/// Waiting periods are counted from [inceptionDate] (first start, before any
/// renewals). When the renewals had a break, they are counted from the start date
/// of the uploaded policy document instead. The current policy period itself is
/// read from the document.
///
/// The questions are asked in order, each only when the previous answer needs it:
/// new or renewed → start date (new) / first start date (renewed) →
/// (renewed) renewed every year without a break.
class _UploadedPolicy {
  _UploadedPolicy({required this.fileName, required this.fileId, required this.policyId});

  final String fileName;
  final String fileId;
  final String policyId;
  DateTime? inceptionDate;

  /// false for a new (first-year) policy, true for a renewed one.
  bool? isRenewal;
  bool? renewedWithoutBreak;

  /// Auto-extraction state tracking
  bool isExtracting = false;
  bool isRenewalAutoExtracted = false;
  bool startDateAutoExtracted = false;
  bool noBreakAutoExtracted = false;

  /// Clear the answers that no longer apply after an earlier answer changed.
  void clearAfterRenewalAnswer() {
    if (isRenewal != true && !noBreakAutoExtracted) renewedWithoutBreak = null;
  }

  /// Set new / renewed. The date means something different for each (the
  /// policy's start date vs the very first start date), so a date picked for
  /// the other answer is cleared and asked again.
  void setRenewal(bool value) {
    if (isRenewal != null && isRenewal != value && !startDateAutoExtracted) inceptionDate = null;
    isRenewal = value;
    clearAfterRenewalAnswer();
  }
}

class _UploadPolicyScreenState extends State<UploadPolicyScreen> {
  /// Matches the server's MAX_POLICIES_PER_ANALYSIS limit.
  static const int _maxPolicies = 5;

  final List<_UploadedPolicy> _policies = [];
  bool _isUploading = false;

  /// Pick the date the policy was first taken.
  Future<void> _pickDate(_UploadedPolicy policy) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = policy.inceptionDate;
    final firstDate = DateTime(1970);
    final helpText = policy.isRenewal == true ? 'Date this policy was first taken' : 'Policy start date';
    final initialDate = (current != null && !current.isAfter(today) && !current.isBefore(firstDate)) ? current : today;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today,
      helpText: helpText,
      confirmText: 'Confirm',
      cancelText: 'Cancel',
    );

    if (picked == null) return;

    setState(() => policy.inceptionDate = picked);
  }

  /// What is still missing for [policy], or null when its continuity answers are complete.
  String? _missingAnswer(_UploadedPolicy policy) {
    if (policy.isRenewal == null) return 'Please answer whether ${policy.fileName} is a new or a renewed policy.';
    if (policy.inceptionDate == null) {
      return policy.isRenewal == true
          ? 'Please select when ${policy.fileName} was first taken.'
          : 'Please select the policy start date for ${policy.fileName}.';
    }
    if (policy.isRenewal == false) return null;
    if (policy.renewedWithoutBreak == null) {
      return 'Please answer whether ${policy.fileName} was renewed every year without a break.';
    }
    return null;
  }

  /// Store the continuity answers on the policy record before the analysis reads them.
  Future<void> _syncContinuity(_UploadedPolicy policy) async {
    try {
      // Answers that do not apply are sent as null so an earlier answer is cleared.
      // Break dates are no longer asked: after a break, the analysis counts cover
      // from the uploaded policy document's start date.
      await ApiClient().dio.put(
        '/policies/${policy.policyId}',
        data: {
          'inceptionDate': policy.inceptionDate!.toIso8601String(),
          'isRenewal': policy.isRenewal,
          'continuousRenewal': policy.isRenewal == true ? policy.renewedWithoutBreak : null,
          'breakStartDate': null,
          'coverRestartDate': null,
        },
      );
    } catch (e) {
      debugPrint("Failed to save policy continuity details: $e");
    }
  }

  /// Upload one or more policy documents. Each file becomes its own policy
  /// record, so the prescription can be compared against all of them.
  Future<void> _pickAndUploadFiles() async {
    final remaining = _maxPolicies - _policies.length;
    if (remaining <= 0) {
      _toast('You can compare up to $_maxPolicies policies at once.');
      return;
    }

    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
      allowMultiple: true,
    );

    final picked = result?.files.where((f) => f.path != null).toList() ?? [];
    if (picked.isEmpty) return;

    // The system file picker cannot cap how many files are ticked, so an
    // over-limit selection is rejected as a whole (never silently trimmed)
    // and the user can pick again.
    if (picked.length > remaining) {
      if (!mounted) return;
      final pickAgain = await showConfirmDialog(
        context,
        title: 'Too many files selected',
        message:
            'You selected ${picked.length} files, but you can add only $remaining more '
            '${remaining == 1 ? 'policy' : 'policies'} (up to $_maxPolicies in total). '
            'Please select up to $remaining ${remaining == 1 ? 'file' : 'files'}.',
        confirmLabel: 'Select again',
        icon: Icons.filter_5_rounded,
      );
      if (pickAgain && mounted) await _pickAndUploadFiles();
      return;
    }
    final files = picked;

    setState(() => _isUploading = true);
    try {
      for (final file in files) {
        await _uploadOne(file);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Upload a single file and create its policy record. A failure on one file
  /// leaves the policies already added untouched.
  Future<void> _uploadOne(PlatformFile file) async {
    String? fileId;
    try {
      final formData = FormData.fromMap({'file': await MultipartFile.fromFile(file.path!)});

      final response = await ApiClient().dio.post('/upload', data: formData);
      if (response.statusCode != 200) {
        _toast('Could not upload ${file.name}.', tone: AppTone.danger);
        return;
      }

      fileId = response.data['fileId'].toString();
      final isImageBased =
          response.data['isImageBased'] == true ||
          file.name.toLowerCase().endsWith('.jpg') ||
          file.name.toLowerCase().endsWith('.jpeg') ||
          file.name.toLowerCase().endsWith('.png');

      final agreementData = await DeviceAppInfo.buildAgreementData();
      final policyResponse = await ApiClient().dio.post(
        '/policies',
        data: {
          'insuranceCompany': '',
          'policyNumber': '',
          'policyName': 'Uploaded Policy',
          'gridFsFileId': fileId,
          'originalFileName': file.name,
          'agreement': agreementData,
        },
      );

      final newPolicyId = (policyResponse.data['_id'] ?? policyResponse.data['id']).toString();

      await SharedPrefs.instance.setBool('policy_is_image_based', isImageBased);

      if (!mounted) return;
      final newPolicy = _UploadedPolicy(fileName: file.name, fileId: fileId!, policyId: newPolicyId);
      setState(() {
        _policies.add(newPolicy);
      });

      // Extract details automatically from the uploaded document
      _extractPolicyDetails(newPolicy);
    } on DioException catch (e) {
      await _rollbackUpload(fileId);
      final offline =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      _toast(
        offline
            ? 'Unable to connect to the server. Please check your internet connection and try again.'
            : 'Our servers could not process ${file.name}. Please try again later.',
        tone: AppTone.danger,
      );
    } catch (e) {
      debugPrint("Failed to save policy record: $e");
      await _rollbackUpload(fileId);
      _toast('Could not add ${file.name}. Please try again.', tone: AppTone.danger);
    }
  }

  Future<void> _extractPolicyDetails(_UploadedPolicy policy) async {
    setState(() => policy.isExtracting = true);
    try {
      final response = await ApiClient().dio.post('/policies/${policy.policyId}/extract-details');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final extractedFields = data['extractedFields'] as Map<String, dynamic>? ?? {};

        DateTime? parsedDate;
        if (data['startDate'] != null) {
          try {
            parsedDate = DateTime.parse(data['startDate'].toString());
          } catch (_) {
            try {
              parsedDate = DateFormat('dd-MM-yyyy').parse(data['startDate'].toString());
            } catch (_) {}
          }
        }

        if (mounted && _policies.contains(policy)) {
          setState(() {
            if (extractedFields['isRenewal'] == true && data['isRenewal'] != null) {
              policy.isRenewal = data['isRenewal'] == true;
              policy.isRenewalAutoExtracted = true;
            }
            if (extractedFields['startDate'] == true && parsedDate != null) {
              policy.inceptionDate = parsedDate;
              policy.startDateAutoExtracted = true;
            }
            if (extractedFields['renewedWithoutBreak'] == true && data['renewedWithoutBreak'] != null) {
              policy.renewedWithoutBreak = data['renewedWithoutBreak'] == true;
              policy.noBreakAutoExtracted = true;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Policy detail extraction failed: $e");
    } finally {
      if (mounted && _policies.contains(policy)) {
        setState(() => policy.isExtracting = false);
      }
    }
  }

  Future<void> _rollbackUpload(String? fileId) async {
    if (fileId == null) return;
    try {
      await ApiClient().dio.delete('/upload/$fileId');
    } catch (deleteError) {
      debugPrint("Failed to rollback uploaded file: $deleteError");
    }
  }

  Future<void> _removePolicy(_UploadedPolicy policy) async {
    setState(() => _policies.remove(policy));
    try {
      await ApiClient().dio.delete('/policies/${policy.policyId}');
    } catch (e) {
      debugPrint("Failed to delete removed policy: $e");
    }
  }

  void _toast(String message, {AppTone tone = AppTone.warning}) {
    if (!mounted) return;
    showAppSnackBar(context, message, tone: tone);
  }

  Future<void> _analyzeDocuments() async {
    if (_isUploading) return;
    if (_policies.isEmpty) {
      _toast('Please upload at least one policy document.');
      return;
    }

    if (_policies.any((p) => p.isExtracting)) {
      showAppSnackBar(context, 'Please wait while we finish reading your policy details.', tone: AppTone.info);
      return;
    }

    for (final policy in _policies) {
      final missing = _missingAnswer(policy);
      if (missing != null) {
        showAppSnackBar(context, missing, tone: AppTone.warning);
        return;
      }
    }

    // Make sure the answers are stored before the analysis reads them.
    for (final policy in _policies) {
      await _syncContinuity(policy);
    }

    final prefs = SharedPrefs.instance;
    await prefs.remove('policy_path');

    // One policy keeps the original single-analysis flow; several go to the
    // comparison screen, exactly as selecting saved policies does.
    if (_policies.length == 1) {
      await prefs.setString('policy_id', _policies.first.policyId);
      await prefs.remove('policy_ids');
      if (mounted) context.push('/analysis');
    } else {
      await prefs.setString('policy_ids', jsonEncode(_policies.map((p) => p.policyId).toList()));
      await prefs.remove('policy_id');
      if (mounted) context.push('/analysis-multi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Upload Policy'),
      ),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepHeader(current: 3, total: 3, label: 'Policy'),
                const SizedBox(height: AppSpacing.xl),
                Text('Add your insurance policy', style: context.text.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Upload one or more insurance policy documents. Add several to compare them against the same prescription.",
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Uploaded policies — each one keeps its own start date, because
                // the waiting-period checks are per policy.
                if (_policies.isNotEmpty) ...[
                  SectionHeader(
                    title: _policies.length == 1 ? "1 policy added" : "${_policies.length} policies added",
                    subtitle: 'Answer the questions below for each policy',
                    trailing: Text(
                      '${_policies.length}/$_maxPolicies',
                      style: context.text.labelMedium?.copyWith(color: p.textTertiary),
                    ),
                  ),
                  ..._policies.map((policy) => _buildPolicyTile(policy: policy)),
                  const SizedBox(height: AppSpacing.xs),
                ],

                // Upload Area with Dashed Border
                Semantics(
                  button: true,
                  label: _policies.isEmpty ? 'Tap to upload PDF or Image' : 'Tap to add another policy',
                  child: Material(
                    color: p.surface,
                    borderRadius: AppRadius.lgAll,
                    child: InkWell(
                      onTap: _isUploading ? null : _pickAndUploadFiles,
                      borderRadius: AppRadius.lgAll,
                      child: CustomPaint(
                        painter: DashedBorderPainter(
                          color: p.borderStrong,
                          strokeWidth: 1.5,
                          gap: 6,
                          radius: AppRadius.lg,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: _policies.isEmpty ? AppSpacing.xxl : AppSpacing.lg,
                            horizontal: AppSpacing.lg,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
                                child: _isUploading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2.6),
                                      )
                                    : Icon(
                                        _policies.isEmpty ? Icons.note_add_outlined : Icons.add_rounded,
                                        size: 28,
                                        color: p.primary,
                                      ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                _isUploading
                                    ? 'Uploading…'
                                    : (_policies.isEmpty ? 'Tap to upload PDF or Image' : 'Tap to add another policy'),
                                textAlign: TextAlign.center,
                                style: context.text.titleSmall,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Select up to ${_maxPolicies - _policies.length} '
                                '${_maxPolicies - _policies.length == 1 ? 'file' : 'files'} · '
                                'max $_maxPolicies policies · 10MB each',
                                textAlign: TextAlign.center,
                                style: context.text.bodySmall,
                              ),
                              if (_isUploading) ...[
                                const SizedBox(height: AppSpacing.md),
                                const ClipRRect(
                                  borderRadius: AppRadius.pillAll,
                                  child: LinearProgressIndicator(minHeight: 4),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
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
            onPressed: _analyzeDocuments, // Finalize and go to analysis loading/results
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _policies.length > 1 ? 'Compare ${_policies.length} Policies' : 'Analyze Coverage',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.insights_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One uploaded policy: its file name, its own start date and a way to drop it.
  Widget _buildPolicyTile({required _UploadedPolicy policy}) {
    final p = context.palette;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      borderColor: p.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const IconTile(icon: Icons.description_outlined, size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  policy.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(height: 1.35, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _removePolicy(policy),
                  icon: Icon(Icons.delete_outline_rounded, color: p.danger.fg, size: 22),
                  tooltip: 'Remove',
                ),
              ),
            ],
          ),
          if (policy.isExtracting) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Reading document details...',
                  style: context.text.bodySmall?.copyWith(color: p.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: p.border),

          // While the document is being read, nothing can be entered by hand: details found
          // in the PDF are filled in and locked, and only what is missing is asked afterwards.
          if (policy.isExtracting)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                "Please wait while we read your policy. Any details we can't find in the "
                'document will be asked here for you to fill in.',
                style: context.text.bodySmall,
              ),
            )
          else ...[
            // 1. New or renewed decides which date is asked next.
            _questionBlock(
              label: 'Is this a new policy or a renewed policy? *',
              child: policy.isRenewalAutoExtracted
                  ? _readOnlyField(
                      value: policy.isRenewal == true ? 'Renewed' : 'New (first year)',
                      icon: policy.isRenewal == true ? Icons.autorenew_rounded : Icons.fiber_new_rounded,
                    )
                  : _twoChoice(
                      value: policy.isRenewal,
                      firstLabel: 'New (first year)',
                      firstValue: false,
                      secondLabel: 'Renewed',
                      secondValue: true,
                      onChanged: (v) => setState(() => policy.setRenewal(v)),
                    ),
            ),

            // 2. The date: the policy's start date (new), or the very first start date (renewed).
            //    Waiting periods are counted from this date, not from the current renewal.
            if (policy.isRenewal != null)
              _questionBlock(
                label: policy.isRenewal == true ? 'When was this policy first taken? *' : 'Policy Start Date *',
                helper: policy.isRenewal == true
                    ? 'The very first start date of this policy, before any renewals.'
                    : 'The date this policy started, as shown on your policy document.',
                child: policy.startDateAutoExtracted && policy.inceptionDate != null
                    ? _readOnlyField(
                        value: DateFormat('dd-MM-yyyy').format(policy.inceptionDate!),
                        icon: Icons.calendar_month_rounded,
                      )
                    : _dateField(
                        value: policy.inceptionDate,
                        placeholder: policy.isRenewal == true
                            ? 'Select first start date *'
                            : 'Select policy start date *',
                        onTap: () => _pickDate(policy),
                      ),
              ),

            // 3. Renewed only: renewed every year without a break?
            if (policy.isRenewal == true)
              _questionBlock(
                label: 'Has this policy been renewed every year without a break? *',
                helper: 'Answer Yes if you moved from another insurance company without any gap (portability).',
                child: policy.noBreakAutoExtracted && policy.renewedWithoutBreak != null
                    ? _readOnlyField(
                        value: policy.renewedWithoutBreak == true ? 'Yes' : 'No',
                        icon: policy.renewedWithoutBreak == true
                            ? Icons.verified_user_outlined
                            : Icons.warning_amber_rounded,
                      )
                    : _twoChoice(
                        value: policy.renewedWithoutBreak,
                        firstLabel: 'Yes',
                        firstValue: true,
                        secondLabel: 'No',
                        secondValue: false,
                        onChanged: (v) => setState(() {
                          policy.renewedWithoutBreak = v;
                          policy.clearAfterRenewalAnswer();
                        }),
                      ),
              ),
            if (policy.isRenewal == true && policy.renewedWithoutBreak == false) ...[
              const SizedBox(height: AppSpacing.md),
              _coverageGapNotice(),
            ],
          ],
        ],
      ),
    );
  }

  /// One question: label, optional helper text, then its input — same spacing everywhere.
  Widget _questionBlock({required String label, String? helper, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: context.text.titleSmall?.copyWith(height: 1.4)),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(helper, textAlign: TextAlign.start, style: context.text.bodySmall),
          ],
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }

  /// Shown when a renewed policy had a break: cover is counted from the uploaded
  /// policy's own start date instead of the first start date.
  Widget _coverageGapNotice() {
    return const InfoBanner(
      tone: AppTone.warning,
      icon: Icons.info_outline_rounded,
      padding: EdgeInsets.all(AppSpacing.sm),
      message:
          'You have a coverage gap in your policy continuity. So the coverage analysis will check '
          'your prescription against this policy from the start date of the uploaded policy document.',
    );
  }

  Widget _readOnlyField({required String value, required IconData icon}) {
    final p = context.palette;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: p.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const StatusBadge(
            label: 'Auto-extracted from PDF',
            tone: AppTone.verify,
            icon: Icons.lock_outline_rounded,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _dateField({required DateTime? value, required String placeholder, required VoidCallback onTap}) {
    final p = context.palette;
    final hasValue = value != null;
    return Material(
      color: p.surfaceMuted,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 20, color: p.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hasValue ? DateFormat('dd-MM-yyyy').format(value) : placeholder,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? p.textPrimary : p.textTertiary,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: p.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _twoChoice({
    required bool? value,
    required String firstLabel,
    required bool firstValue,
    required String secondLabel,
    required bool secondValue,
    required ValueChanged<bool> onChanged,
  }) {
    final p = context.palette;
    Widget option(String label, bool option) {
      final selected = value == option;
      return Expanded(
        child: Material(
          color: selected ? p.primarySoft : p.surface,
          borderRadius: AppRadius.mdAll,
          child: InkWell(
            onTap: () => onChanged(option),
            borderRadius: AppRadius.mdAll,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: selected ? p.primary : p.border, width: selected ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18,
                    color: selected ? p.primary : p.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? p.primary : p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(firstLabel, firstValue),
        const SizedBox(width: AppSpacing.xs),
        option(secondLabel, secondValue),
      ],
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
