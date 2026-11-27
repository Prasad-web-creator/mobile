import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:claimsupport/core/config/app_config_provider.dart';
import 'package:claimsupport/core/design/app_icons.dart';
import 'package:claimsupport/core/design/design.dart';
import 'package:claimsupport/core/design/widgets/app_buttons.dart';
import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/app_sections.dart';
import 'package:claimsupport/core/design/widgets/app_sheet_content.dart';
import 'package:claimsupport/core/design/widgets/app_shells.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/features/analysis/data/repositories/new_check_repository.dart';
import 'package:claimsupport/features/analysis/presentation/widgets/analysis_exit_guard.dart';
import 'package:claimsupport/features/analysis/presentation/widgets/document_consent.dart';
import 'package:claimsupport/features/checks/presentation/check_completion_monitor.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/documents/presentation/document_summary.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';

enum _DocumentSource { camera, file, photos, typed }

const _unreadable = "Couldn't read this document. Try a clearer photo.";

class NewCheckScreen extends ConsumerStatefulWidget {
  const NewCheckScreen({
    super.key,
    this.addPrescriptionOnly = false,
    this.initialPrescriptionId,
    this.initialPolicyIds = const {},
  });

  final bool addPrescriptionOnly;
  final String? initialPrescriptionId;
  final Set<String> initialPolicyIds;

  @override
  ConsumerState<NewCheckScreen> createState() => _NewCheckScreenState();
}

class _NewCheckScreenState extends ConsumerState<NewCheckScreen> {
  final _imagePicker = ImagePicker();
  late final VoidCallback _removeExitGuard;
  Future<bool>? _startExit;
  String? _startingJobId;
  bool _startCancelled = false;
  String _requestId = _newRequestId();
  String? _jobId;
  Prescription? _treatment;
  final _newTreatments = <String, Prescription>{};
  final _newPolicies = <String, Policy>{};
  late Set<String> _policyIds = widget.initialPolicyIds;
  bool _choosePolicies = false;
  bool _busy = false;
  bool _starting = false;
  String? _pendingName;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _removeExitGuard = registerAnalysisExitGuard(ref, '/check/new', _confirmStartingExit);
    if (widget.addPrescriptionOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _addDocument(ref.read(appConfigProvider).value ?? AppRuntimeConfig.defaults);
        if (mounted && !_isError) context.pop();
      });
    }
  }

  @override
  void dispose() {
    _removeExitGuard();
    super.dispose();
  }

  Future<bool> _confirmStartingExit() {
    final job = _startingJobId;
    if (job == null) return Future.value(true);
    return _startExit ??= _stopStartingJob(job).whenComplete(() => _startExit = null);
  }

  Future<bool> _stopStartingJob(String jobId) async {
    if (!await confirmStoppingAnalysis(context) || !mounted) return false;
    try {
      await ref.read(newCheckRepositoryProvider).cancelJob(jobId);
      if (mounted) {
        _startCancelled = true;
        _startingJobId = null;
        _resetJob();
      }
      return true;
    } catch (_) {
      _showMessage("Couldn't confirm the analysis stopped. Try again.", error: true);
      return false;
    }
  }

  static String _newRequestId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _showMessage(String message, {required bool error}) {
    if (mounted) {
      setState(() {
        _message = message;
        _isError = error;
      });
    }
  }

  void _resetJob() {
    _jobId = null;
    _requestId = _newRequestId();
  }

  Future<String> _ensureJob(NewCheckRepository repository) async =>
      _jobId ??= await repository.createJob(_requestId);

  static bool _isJobExpired(Object error) =>
      error is DioException && const {403, 404, 410}.contains(error.response?.statusCode);

  Future<XFile?> _pickDocument(_DocumentSource source) async {
    if (source == _DocumentSource.file) {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', if (_choosePolicies) 'docx'],
      );
      return picked?.xFiles.singleOrNull;
    }
    return _imagePicker.pickImage(
      source: source == _DocumentSource.camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 95,
      requestFullMetadata: false,
    );
  }

  Future<bool?> _confirmDuplicateFile(String filename, {required bool isPolicy}) => AppSheet.show<bool>(
    context: context,
    title: 'Already saved',
    bodyBuilder: (ctx) => AppSheetList(
      rows: [
        Text(
          '${isPolicy ? 'A policy' : 'A prescription'} from "$filename" is already saved.',
          style: AppTextStyles.bodyStrong.copyWith(color: ctx.colors.textPrimary),
        ),
        AppButton(label: 'Use saved', onPressed: () => Navigator.of(ctx).pop(false)),
        AppButton(
          label: 'Save another copy',
          style: AppButtonStyle.secondary,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );

  Future<bool?> _confirmDuplicatePolicyNumber(Policy candidate, Policy existing) {
    final existingName = DocumentSummary.policy(existing).title;
    final numLabel = candidate.policyNumber.trim();
    return AppSheet.show<bool>(
      context: context,
      title: 'Policy already saved',
      bodyBuilder: (ctx) => AppSheetList(
        rows: [
          Text(
            numLabel.isNotEmpty
                ? '$existingName ($numLabel) is already in your saved policies.'
                : '$existingName is already in your saved policies.',
            style: AppTextStyles.bodyStrong.copyWith(color: ctx.colors.textPrimary),
          ),
          AppButton(label: 'Use saved policy', onPressed: () => Navigator.of(ctx).pop(false)),
          AppButton(
            label: 'Save anyway',
            style: AppButtonStyle.secondary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmWrongDocumentType({required String detectedType}) {
    final isDetectedPolicy = detectedType == 'policy';
    return AppSheet.show<bool>(
      context: context,
      title: isDetectedPolicy ? 'This looks like a policy' : 'This looks like a prescription',
      bodyBuilder: (ctx) => AppSheetConfirmation(
        message: isDetectedPolicy
            ? 'You selected a policy document in the prescription step. Save it to your Policies list instead?'
            : 'You selected a prescription document in the policy step. Save it to your Prescriptions list instead?',
        actionLabel: isDetectedPolicy ? 'Save to Policies' : 'Save to Prescriptions',
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  Future<void> _savePolicyRecord(
    NewCheckRepository repository,
    String jobId,
    String filename,
    List<int> bytes,
  ) async {
    final policy = await repository.uploadPolicy(jobId: jobId, filename: filename, bytes: bytes);
    if (!mounted) return;
    final existing = await repository.findDuplicatePolicyByNumber(policy);
    if (!mounted) return;
    if (existing != null) {
      final keepNew = await _confirmDuplicatePolicyNumber(policy, existing);
      if (!mounted) return;
      if (keepNew != true) {
        await repository.discardPolicy(policy.id);
        if (!mounted) return;
        setState(() {
          _newPolicies[existing.id] = existing;
        });
        _showMessage('Kept your saved policy.', error: false);
        return;
      }
    }
    setState(() {
      _newPolicies[policy.id] = policy;
    });
    ref.invalidate(checkPoliciesProvider);
    ref.invalidate(policiesProvider);
  }

  Future<void> _saveTreatmentRecord(
    NewCheckRepository repository,
    String jobId,
    String filename,
    List<int> bytes, {
    bool selectInList = true,
  }) async {
    final treatment = await repository.uploadTreatment(jobId: jobId, filename: filename, bytes: bytes);
    if (!mounted) return;
    setState(() {
      _newTreatments[treatment.id] = treatment;
      if (selectInList) _treatment = treatment;
    });
    ref.invalidate(checkTreatmentsProvider);
    ref.invalidate(prescriptionProvider);
  }

  Future<void> _addDocument(AppRuntimeConfig config) async {
    if (_busy || _starting) return;
    final isPolicy = _choosePolicies;
    final repository = ref.read(newCheckRepositoryProvider);
    setState(() {
      _busy = true;
      _message = null;
      _isError = false;
    });
    try {
      final canScan =
          kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      final source = await AppSheet.show<_DocumentSource>(
        context: context,
        title: isPolicy ? 'Add a policy' : 'Add a prescription',
        showClose: true,
        bodyBuilder: (context) {
          final type = isPolicy ? DocumentCardType.policy : DocumentCardType.prescription;
          return AppRowGroup(
            onSheet: true,
            rows: [
              AppDocumentRow(
                type: type,
                title: 'Scan',
                meta: 'Use the camera',
                leadingIcon: AppIcons.scan,
                grouped: true,
                onTap: canScan ? () => Navigator.of(context).pop(_DocumentSource.camera) : null,
              ),
              AppDocumentRow(
                type: type,
                title: 'Upload file',
                meta: 'PDF or image',
                leadingIcon: Icons.file_upload_outlined,
                grouped: true,
                onTap: () => Navigator.of(context).pop(_DocumentSource.file),
              ),
              AppDocumentRow(
                type: type,
                title: 'Photos',
                meta: 'Pick from your gallery',
                leadingIcon: Icons.photo_outlined,
                grouped: true,
                onTap: () => Navigator.of(context).pop(_DocumentSource.photos),
              ),
              if (!isPolicy)
                AppDocumentRow(
                  type: type,
                  title: 'Type it in',
                  meta: 'No document? Describe the treatment',
                  leadingIcon: AppIcons.pencil,
                  grouped: true,
                  onTap: () => Navigator.of(context).pop(_DocumentSource.typed),
                ),
            ],
          );
        },
      );
      if (!mounted || source == null) return;
      if (source == _DocumentSource.typed) {
        final saved = await context.push<Prescription>('/prescriptions/type');
        if (mounted && saved != null) {
          setState(() {
            _newTreatments[saved.id] = saved;
            _treatment = saved;
          });
        }
        return;
      }
      final file = await _pickDocument(source);
      if (!mounted || file == null) return;
      final length = await file.length();
      if (!mounted) return;
      if (!config.acceptsFileSize(length)) {
        _showMessage(config.uploadLimitMessage, error: true);
        return;
      }

      // Phase F §0.7: Warn before saving if a file with the same name & size is already saved.
      if (isPolicy) {
        final existing = await repository.findMatchingPolicyFile(file.name, length);
        if (!mounted) return;
        if (existing != null) {
          final saveAnyway = await _confirmDuplicateFile(file.name, isPolicy: true);
          if (!mounted || saveAnyway == null) return;
          if (!saveAnyway) {
            setState(() {
              _newPolicies[existing.id] = existing;
            });
            return;
          }
        }
      } else {
        final existing = await repository.findMatchingPrescriptionFile(file.name, length);
        if (!mounted) return;
        if (existing != null) {
          final saveAnyway = await _confirmDuplicateFile(file.name, isPolicy: false);
          if (!mounted || saveAnyway == null) return;
          if (!saveAnyway) {
            setState(() {
              _newTreatments[existing.id] = existing;
              _treatment = existing;
            });
            return;
          }
        }
      }

      if (!await confirmDocumentConsent(context) || !mounted) return;
      final jobId = await _ensureJob(repository);
      if (!mounted) return;
      setState(() => _pendingName = isPolicy ? 'New policy' : 'New prescription');
      final bytes = await file.readAsBytes();

      if (isPolicy) {
        await _savePolicyRecord(repository, jobId, file.name, bytes);
      } else {
        await _saveTreatmentRecord(repository, jobId, file.name, bytes);
      }
      ref.invalidate(dashboardStatsProvider);
    } on WrongDocumentTypeException catch (wrong) {
      if (!mounted) return;
      setState(() => _pendingName = null);
      final moveToRightList = await _confirmWrongDocumentType(detectedType: wrong.detectedType);
      if (!mounted || moveToRightList != true) return;
      final jobId = await _ensureJob(repository);
      if (!mounted) return;
      setState(() => _pendingName = wrong.detectedType == 'policy' ? 'New policy' : 'New prescription');
      if (wrong.detectedType == 'policy') {
        await _savePolicyRecord(repository, jobId, wrong.filename, wrong.bytes);
        _showMessage('Saved to your Policies list.', error: false);
      } else {
        await _saveTreatmentRecord(repository, jobId, wrong.filename, wrong.bytes, selectInList: false);
        _showMessage('Saved to your Prescriptions list.', error: false);
      }
      ref.invalidate(dashboardStatsProvider);
    } on DuplicateCheckPolicy {
      _showMessage('This policy is already saved.', error: false);
    } on UnreadableCheckDocument {
      if (!isPolicy) _resetJob();
      _showMessage(_unreadable, error: true);
    } on DioException catch (error) {
      if (_isJobExpired(error)) _resetJob();
      _showMessage(
        error.response?.statusCode == 413
            ? config.uploadLimitMessage
            : const {400, 415, 422}.contains(error.response?.statusCode)
            ? _unreadable
            : "Couldn't add this document. Try again.",
        error: true,
      );
    } catch (_) {
      _showMessage("Couldn't add this document. Try again.", error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingName = null;
        });
      }
    }
  }

  Future<void> _start(List<String> selection) async {
    final treatment = _treatment;
    if (treatment == null || selection.isEmpty || _starting || _busy) return;
    final repository = ref.read(newCheckRepositoryProvider);
    final monitor = ref.read(checkCompletionMonitorProvider.notifier);
    setState(() {
      _starting = true;
      _startCancelled = false;
      _message = null;
    });
    try {
      final jobId = await _ensureJob(repository);
      if (!mounted) return;
      _startingJobId = jobId;
      try {
        await repository.start(jobId, treatment.id, selection);
      } finally {
        final exit = _startExit;
        if (exit != null) await exit;
        _startingJobId = null;
      }
      if (!mounted || _startCancelled) return;
      monitor.track(jobId);
      context.pushReplacement('/check/processing/$jobId');
    } catch (error) {
      if (_startCancelled) return;
      if (_isJobExpired(error)) _resetJob();
      _showMessage("Couldn't start this check. Please try again.", error: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  static bool _policyAvailable(Policy policy) =>
      policy.id.isNotEmpty &&
      DocumentSummary.policy(policy).state == AppDocumentState.ready &&
      !const {'inactive', 'cancelled', 'canceled'}.contains(policy.status.trim().toLowerCase());

  void _togglePolicy(String id, Set<String> selected, int limit) {
    if (_busy || _starting) return;
    final updated = {...selected};
    if (!updated.remove(id)) {
      if (updated.length >= limit) {
        final config = ref.read(appConfigProvider).value ?? AppRuntimeConfig.defaults;
        _showMessage(config.policyLimitMessage, error: false);
        return;
      }
      updated.add(id);
    }
    setState(() {
      _policyIds = updated;
      _message = null;
    });
  }

  void _setStep(bool choosePolicies) => setState(() {
    _choosePolicies = choosePolicies;
    _message = null;
  });

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider).value ?? AppRuntimeConfig.defaults;
    final treatmentsState = ref.watch(checkTreatmentsProvider);
    final policiesState = _choosePolicies ? ref.watch(checkPoliciesProvider) : null;
    final savedTreatments =
        treatmentsState.value ??
        (treatmentsState.hasError ? ref.read(prescriptionProvider.notifier).cachedPage?.docs : null) ??
        const <Prescription>[];
    final savedPolicies =
        policiesState?.value ??
        (policiesState?.hasError == true ? ref.read(policiesProvider.notifier).cachedPage?.docs : null) ??
        const <Policy>[];
    final treatments = {
      for (final item in savedTreatments)
        if (item.id.isNotEmpty) item.id: item,
      ..._newTreatments,
    }.values;
    final selectedTreatment =
        _treatment ??
        treatments
            .where(
              (item) =>
                  item.id == widget.initialPrescriptionId &&
                  DocumentSummary.prescription(item).state == AppDocumentState.ready,
            )
            .firstOrNull;
    final policies = {
      for (final item in savedPolicies)
        if (item.id.isNotEmpty) item.id: item,
      ..._newPolicies,
    }.values;
    final eligible = policies.where(_policyAvailable).map((policy) => policy.id).toSet();
    final selected = _policyIds.where(eligible.contains).take(config.maxPolicies).toSet();
    final interactionLocked = _busy || _starting;
    final message = _message;
    final pendingName = _pendingName;
    final type = _choosePolicies ? DocumentCardType.policy : DocumentCardType.prescription;

    return PopScope<Object?>(
      canPop: !_choosePolicies,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _choosePolicies && !interactionLocked) _setStep(false);
      },
      child: FlowShell(
        title: _choosePolicies ? 'Select policies' : 'Select prescription',
        step: _choosePolicies ? 2 : 1,
        onClose: _close,
        action: _choosePolicies
            ? AppIconButton(
                icon: AppIcons.caretLeft,
                label: 'Back to treatment',
                onPressed: interactionLocked ? null : () => _setStep(false),
              )
            : null,
        body: ListView(
          key: ValueKey(type),
          padding: const EdgeInsets.fromLTRB(
            DsSpace.screenPadding,
            0,
            DsSpace.screenPadding,
            DsSpace.sectionGap,
          ),
          children: [
            Text(
              _choosePolicies
                  ? 'Pick up to ${config.maxPolicies} to see which covers more.'
                  : "A prescription, doctor's advice or hospital estimate.",
              style: AppTextStyles.label.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: DsSpace.s16),
            AppDocumentRow(
              type: type,
              title: 'Add new',
              meta: 'Scan, upload or pick a photo',
              addAction: true,
              onTap: interactionLocked ? null : () => _addDocument(config),
            ),
            const SizedBox(height: DsSpace.s8),
            if (pendingName != null) ...[
              AppDocumentRow(type: type, title: pendingName, state: AppDocumentState.reading, onTap: null),
              const SizedBox(height: DsSpace.s8),
            ],
            if (message != null) ...[
              AppInlineBanner(
                kind: _isError ? AppInlineBannerKind.error : AppInlineBannerKind.info,
                message: message,
              ),
              const SizedBox(height: DsSpace.s12),
            ],
            const SizedBox(height: DsSpace.s8),
            Text(
              'Saved · ${_choosePolicies ? policies.length : treatments.length}',
              style: AppTextStyles.captionRegular.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: DsSpace.s8),
            if (_choosePolicies) ...[
              if (policiesState?.hasError == true)
                _LoadIssue(
                  message: "Couldn't load your saved policies.",
                  cached: policies.isNotEmpty,
                  retry: () => ref.invalidate(checkPoliciesProvider),
                ),
              if (policiesState?.isLoading == true && policies.isEmpty) const _DocumentPlaceholder(),
              for (final policy in policies) ...[
                _ChoiceRow(
                  summary: DocumentSummary.policy(policy),
                  selected: selected.contains(policy.id),
                  onTap: _policyAvailable(policy) && !interactionLocked
                      ? () => _togglePolicy(policy.id, selected, config.maxPolicies)
                      : null,
                ),
                const SizedBox(height: DsSpace.s8),
              ],
            ] else ...[
              if (treatmentsState.hasError)
                _LoadIssue(
                  message: "Couldn't load your saved treatment documents.",
                  cached: treatments.isNotEmpty,
                  retry: () => ref.invalidate(checkTreatmentsProvider),
                ),
              if (treatmentsState.isLoading && treatments.isEmpty) const _DocumentPlaceholder(),
              for (final treatment in treatments) ...[
                _ChoiceRow(
                  summary: DocumentSummary.prescription(treatment),
                  selected: selectedTreatment?.id == treatment.id,
                  onTap:
                      interactionLocked ||
                          DocumentSummary.prescription(treatment).state != AppDocumentState.ready
                      ? null
                      : () => setState(() => _treatment = treatment),
                ),
                const SizedBox(height: DsSpace.s8),
              ],
            ],
          ],
        ),
        bottomAction: AppButton(
          label: _choosePolicies
              ? (_starting
                    ? 'Starting check…'
                    : 'Check ${selected.length} ${selected.length == 1 ? 'policy' : 'policies'}')
              : 'Continue',
          busy: _starting,
          onPressed: interactionLocked
              ? null
              : _choosePolicies
              ? selected.isEmpty
                    ? null
                    : () => _start(selected.toList())
              : selectedTreatment == null
              ? null
              : () {
                  _treatment = selectedTreatment;
                  _setStep(true);
                },
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.summary, required this.selected, required this.onTap});

  final DocumentSummary summary;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: summary.state == AppDocumentState.expired ? 0.6 : 1,
    child: AppDocumentRow(
      type: summary.type,
      title: summary.title,
      meta: summary.meta,
      timestamp: summary.timestamp,
      state: summary.state,
      selected: selected,
      checkbox: summary.type == DocumentCardType.policy,
      onTap: onTap,
    ),
  );
}

class _DocumentPlaceholder extends StatelessWidget {
  const _DocumentPlaceholder();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: DsSpace.s8),
    child: AppSkeleton(kind: AppSkeletonKind.row),
  );
}

class _LoadIssue extends StatelessWidget {
  const _LoadIssue({required this.message, required this.cached, required this.retry});

  final String message;
  final bool cached;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: DsSpace.s8),
    child: AppInlineBanner(
      kind: cached ? AppInlineBannerKind.offline : AppInlineBannerKind.error,
      message: cached ? 'Showing saved documents. Try refreshing when you reconnect.' : message,
      onRetry: retry,
    ),
  );
}
