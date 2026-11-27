import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/config/app_config_provider.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/utils/device_app_info.dart';
import 'package:claimsupport/core/widgets/app_widgets.dart';

class UploadPolicyScreen extends ConsumerStatefulWidget {
  const UploadPolicyScreen({super.key});

  @override
  ConsumerState<UploadPolicyScreen> createState() => _UploadPolicyScreenState();
}

/// One policy the user has uploaded in this session, with its own continuity answers.
///
/// Waiting periods are counted from [inceptionDate] (first start, before any
/// renewals). When the renewals had a break, they are counted from the start date
/// of the uploaded policy document instead. The current policy period itself is
/// read from the document.
///
/// The policy is read right after upload. A question is shown only for an answer
/// the document does not give (or when the user chooses to edit), in order:
/// new or renewed → start date (new) / first start date (renewed) →
/// (renewed) renewed every year without a break.
enum _ReadState { reading, read, notPolicy, failed }

class _UploadedPolicy {
  _UploadedPolicy({required this.fileName, required this.fileId, required this.policyId});

  final String fileName;
  final String fileId;
  final String policyId;
  DateTime? inceptionDate;

  /// false for a new (first-year) policy, true for a renewed one.
  bool? isRenewal;
  bool? renewedWithoutBreak;

  _ReadState readState = _ReadState.reading;

  /// Schedule details read from the document (insurer, number, period, sum insured…).
  Map<String, dynamic> details = const {};

  /// The current period's start in the document, used when the user says "New".
  DateTime? documentStartDate;

  /// Which answers came from the document (and so are not asked).
  bool renewalFromDocument = false;
  bool dateFromDocument = false;
  bool breakFromDocument = false;

  /// The user chose to review and change the answers read from the document.
  bool editing = false;

  bool get isReading => readState == _ReadState.reading;

  /// Clear the answers that no longer apply after an earlier answer changed.
  void clearAfterRenewalAnswer() {
    if (isRenewal != true) {
      renewedWithoutBreak = null;
      breakFromDocument = false;
    }
  }

  /// Set new / renewed. The date means something different for each (the
  /// policy's start date vs the very first start date), so a date picked for
  /// the other answer is cleared — unless the document states the new policy's start.
  void setRenewal(bool value) {
    if (isRenewal != null && isRenewal != value) {
      inceptionDate = null;
      dateFromDocument = false;
    }
    isRenewal = value;
    if (value == false && inceptionDate == null && documentStartDate != null) {
      inceptionDate = documentStartDate;
      dateFromDocument = true;
    }
    clearAfterRenewalAnswer();
  }

  /// Apply the reading of the document returned by `/policies/{id}/extract-details`.
  void applyReading(Map<String, dynamic> data) {
    final isPolicy = data['isPolicy'];
    if (isPolicy == false) {
      readState = _ReadState.notPolicy;
      return;
    }
    final found = (data['extractedFields'] as Map?) ?? const {};
    final raw = data['details'];
    details = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final hints = (data['hints'] as Map?) ?? const {};
    documentStartDate = DateTime.tryParse('${hints['policyStartDate'] ?? ''}');

    if (found['isRenewal'] == true && data['isRenewal'] is bool) {
      isRenewal = data['isRenewal'] as bool;
      renewalFromDocument = true;
    }
    final start = DateTime.tryParse('${data['startDate'] ?? ''}');
    if (found['startDate'] == true && start != null) {
      inceptionDate = start;
      dateFromDocument = true;
    } else if (isRenewal == false && documentStartDate != null) {
      inceptionDate = documentStartDate;
      dateFromDocument = true;
    }
    if (found['renewedWithoutBreak'] == true && data['renewedWithoutBreak'] is bool) {
      renewedWithoutBreak = data['renewedWithoutBreak'] as bool;
      breakFromDocument = true;
    }
    final anything = renewalFromDocument || details.values.any((v) => v != null);
    readState = (isPolicy == true || anything) ? _ReadState.read : _ReadState.failed;
  }

  bool get askRenewal => editing || !renewalFromDocument;
  bool get askDate => editing || !dateFromDocument;
  bool get askBreak => editing || !breakFromDocument;
}

class _UploadPolicyScreenState extends ConsumerState<UploadPolicyScreen> {
  AppRuntimeConfig get _config => ref.read(appConfigProvider).value ?? AppRuntimeConfig.defaults;
  int get _maxPolicies => _config.maxPolicies;

  final List<_UploadedPolicy> _policies = [];
  bool _isUploading = false;

  /// Pick the date the policy was first taken.
  Future<void> _pickDate(_UploadedPolicy policy) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = policy.inceptionDate;
    final firstDate = DateTime(1970);
    final helpText = policy.isRenewal == true ? 'Date this policy was first taken' : 'Policy start date';
    // Open on the document's date when there is no answer yet.
    final candidate = current ?? policy.documentStartDate;
    final initialDate = (candidate != null && !candidate.isAfter(today) && !candidate.isBefore(firstDate))
        ? candidate
        : today;

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

    setState(() {
      policy.inceptionDate = picked;
      policy.dateFromDocument = false;
    });
  }

  /// Read the uploaded policy now, so the user is asked only for what the
  /// document does not state. The reading is stored for the analysis to reuse.
  Future<void> _readPolicy(_UploadedPolicy policy) async {
    try {
      final response = await ApiClient().dio.post(
        '/policies/${policy.policyId}/extract-details',
        // OCR of a scanned policy can take a while.
        options: analysisUploadOptions().copyWith(receiveTimeout: const Duration(minutes: 4)),
      );
      final data = response.data;
      if (!mounted || !_policies.contains(policy)) return;
      setState(() {
        if (data is Map) {
          policy.applyReading(Map<String, dynamic>.from(data));
        } else {
          policy.readState = _ReadState.failed;
        }
      });
    } catch (e) {
      debugPrint('Policy reading failed: $e');
      if (mounted && _policies.contains(policy)) setState(() => policy.readState = _ReadState.failed);
    }
  }

  /// Store the continuity answers on the policy record before the analysis reads them.
  Future<void> _syncContinuity(_UploadedPolicy policy) async {
    // Answers that do not apply are sent as null so an earlier answer is cleared.
    // Break dates are no longer asked: after a break, the analysis counts cover
    // from the uploaded policy document's start date.
    await ApiClient().dio.put(
      '/policies/${policy.policyId}',
      data: {
        'inceptionDate': policy.inceptionDate?.toIso8601String(),
        'isRenewal': policy.isRenewal,
        'continuousRenewal': policy.isRenewal == true ? policy.renewedWithoutBreak : null,
        'breakStartDate': null,
        'coverRestartDate': null,
      },
    );
  }

  /// Upload one or more policy documents. Each file becomes its own policy
  /// record, so the prescription can be compared against all of them.
  Future<void> _pickAndUploadFiles() async {
    final remaining = _maxPolicies - _policies.length;
    if (remaining <= 0) {
      _toast(_config.policyLimitMessage);
      return;
    }

    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
      allowMultiple: true,
    );

    final picked = result?.files.where((f) => f.path != null).toList() ?? [];
    if (!mounted || picked.isEmpty) return;
    if (picked.any((file) => !_config.acceptsFileSize(file.size))) {
      _toast(_config.uploadLimitMessage);
      return;
    }

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
      final formData = FormData.fromMap({'file': await MultipartFile.fromFile(file.path!), 'documentType': 'policy'});

      final response = await ApiClient().dio.post('/upload', data: formData, options: analysisUploadOptions());
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
        options: analysisUploadOptions(),
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
      final newPolicy = _UploadedPolicy(fileName: file.name, fileId: fileId, policyId: newPolicyId);
      setState(() {
        _policies.add(newPolicy);
      });
      unawaited(_readPolicy(newPolicy));
    } on DioException catch (e) {
      await _rollbackUpload(fileId);
      if (e.response?.statusCode == 413) {
        final data = e.response?.data;
        final message = data is Map ? data['message'] : null;
        _toast(message is String ? message : _config.uploadLimitMessage);
        return;
      }
      final offline =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      _toast(
        offline ? friendlyErrorMessage(e) : 'Our servers could not process ${file.name}. Please try again later.',
        tone: AppTone.danger,
      );
    } catch (e) {
      debugPrint("Failed to save policy record: $e");
      await _rollbackUpload(fileId);
      _toast('Could not add ${file.name}. Please try again.', tone: AppTone.danger);
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
    if (_policies.length > _maxPolicies) {
      _toast(_config.policyLimitMessage);
      return;
    }

    if (_policies.any((p) => p.isReading)) {
      _toast('Still reading your policy. This takes a few seconds.', tone: AppTone.info);
      return;
    }

    // Make sure the answers are stored before the analysis reads them.
    try {
      for (final policy in _policies) {
        if (policy.isRenewal != null) await _syncContinuity(policy);
      }
    } catch (_) {
      _toast('Could not save the confirmed policy details. Please try again.', tone: AppTone.danger);
      return;
    }

    final prefs = SharedPrefs.instance;
    await prefs.remove('policy_path');

    await prefs.setString('policy_ids', jsonEncode(_policies.map((p) => p.policyId).toList()));
    await prefs.remove('policy_id');
    if (mounted) context.push('/analysis-multi');
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider).value ?? AppRuntimeConfig.defaults;
    final p = context.palette;

    return FlowShell(
      title: 'Upload Policy',
      step: 3,
      stepCount: 3,
      onClose: () => context.go('/dashboard'),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    subtitle: 'We read the details from each policy',
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
                                'max $_maxPolicies policies · ${config.maxFileSizeMb} MB each',
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
      bottomAction: AppButton(
        label: _policies.length > 1 ? 'Compare ${_policies.length} Policies' : 'Analyze Coverage',
        onPressed: _analyzeDocuments,
        icon: AppIcons.scan,
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
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: p.border),
          if (policy.isReading) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Reading your policy details…', style: context.text.bodyMedium)),
              ],
            ),
          ] else ...[
            ..._readingSummary(policy),
            // 1. New or renewed decides which date is asked next.
            if (policy.askRenewal)
              _questionBlock(
                label: 'Is this a new policy or a renewed policy?',
                child: _twoChoice(
                  value: policy.isRenewal,
                  firstLabel: 'New (first year)',
                  firstValue: false,
                  secondLabel: 'Renewed',
                  secondValue: true,
                  onChanged: (v) => setState(() {
                    policy.renewalFromDocument = false;
                    policy.setRenewal(v);
                  }),
                ),
              ),

            // 2. The date: the policy's start date (new), or the very first start date (renewed).
            //    Waiting periods are counted from this date, not from the current renewal.
            if (policy.isRenewal != null && policy.askDate)
              _questionBlock(
                label: policy.isRenewal == true ? 'When was this policy first taken?' : 'Policy start date',
                helper: policy.isRenewal == true
                    ? 'The very first start date of this policy, before any renewals.'
                    : 'The date this policy started, as shown on your policy document.',
                child: _dateField(
                  value: policy.inceptionDate,
                  placeholder: policy.isRenewal == true ? 'Select first start date' : 'Select policy start date',
                  onTap: () => _pickDate(policy),
                ),
              ),

            // 3. Renewed only: renewed every year without a break?
            if (policy.isRenewal == true && policy.askBreak)
              _questionBlock(
                label: 'Has this policy been renewed every year without a break?',
                helper: 'Answer Yes if you moved from another insurance company without any gap (portability).',
                child: _twoChoice(
                  value: policy.renewedWithoutBreak,
                  firstLabel: 'Yes',
                  firstValue: true,
                  secondLabel: 'No',
                  secondValue: false,
                  onChanged: (v) => setState(() {
                    policy.renewedWithoutBreak = v;
                    policy.breakFromDocument = false;
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

  /// What was read from the document, and a note on what still needs an answer.
  List<Widget> _readingSummary(_UploadedPolicy policy) {
    final p = context.palette;
    String? date(Object? value) {
      final parsed = value is DateTime ? value : DateTime.tryParse('${value ?? ''}');
      return parsed == null ? null : DateFormat('dd-MM-yyyy').format(parsed);
    }

    String? text(Object? value) {
      final s = value?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    switch (policy.readState) {
      case _ReadState.notPolicy:
        return [
          const SizedBox(height: AppSpacing.md),
          const InfoBanner(
            tone: AppTone.warning,
            padding: EdgeInsets.all(AppSpacing.sm),
            message: 'This file does not look like an insurance policy. Check the file, or answer the questions below.',
          ),
        ];
      case _ReadState.failed:
        return [
          const SizedBox(height: AppSpacing.md),
          const InfoBanner(
            tone: AppTone.warning,
            padding: EdgeInsets.all(AppSpacing.sm),
            message: 'We could not read the details from this policy. Please answer the questions below.',
          ),
        ];
      case _ReadState.reading:
        return const [];
      case _ReadState.read:
        break;
    }

    final d = policy.details;
    final amount = d['coverageAmount'];
    final start = date(d['policyStartDate']);
    final end = date(d['policyEndDate']);
    final rows = <(String, String?)>[
      ('Insurer', text(d['insuranceCompany'])),
      ('Plan', text(d['policyName'])),
      ('Policy number', text(d['policyNumber'])),
      ('Policy holder', text(d['policyHolder'])),
      ('Policy period', start == null && end == null ? null : '${start ?? '—'} to ${end ?? '—'}'),
      (
        'Sum insured',
        amount is num && amount > 0
            ? NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount)
            : null,
      ),
      if (!policy.editing && policy.renewalFromDocument)
        ('Policy type', policy.isRenewal == true ? 'Renewed' : 'New (first year)'),
      if (!policy.editing && policy.dateFromDocument && policy.inceptionDate != null)
        (policy.isRenewal == true ? 'First taken on' : 'Start date', date(policy.inceptionDate)),
      if (!policy.editing && policy.breakFromDocument && policy.isRenewal == true)
        ('Renewed without a break', policy.renewedWithoutBreak == true ? 'Yes' : 'No'),
    ].where((row) => row.$2 != null).toList();

    final missing =
        policy.askRenewal ||
        (policy.isRenewal != null && policy.askDate) ||
        (policy.isRenewal == true && policy.askBreak);
    final canEdit = policy.renewalFromDocument || policy.dateFromDocument || policy.breakFromDocument;

    return [
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: p.success.fg),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text('Details from your policy', style: context.text.titleSmall)),
          if (canEdit)
            TextButton(
              onPressed: () => setState(() => policy.editing = !policy.editing),
              child: Text(policy.editing ? 'Done' : 'Edit'),
            ),
        ],
      ),
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 140, child: Text(row.$1, style: context.text.bodySmall)),
              Expanded(
                child: Text(row.$2!, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      if (missing && !policy.editing) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your policy does not state the following, so please answer:',
          style: context.text.bodySmall?.copyWith(color: p.textSecondary),
        ),
      ],
    ];
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
