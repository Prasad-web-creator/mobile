import 'package:claimsupport/core/localization/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:claimsupport/core/localization/translation_mapper.dart';

import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/core/utils/activity_timestamp.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';

@immutable
class DocumentSummary {
  const DocumentSummary._(this.type, this.title, this.meta, this.state, {this.timestamp});

  factory DocumentSummary.prescription(Prescription record, {DateTime? now, AppLocalizations? l10n}) {
    l10n ??= lookupAppLocalizations(const Locale('en'));
    final isTyped = record.isManual;
    final title = isTyped
        ? (_firstLine(record.manualText ?? record.extractedPrescriptionText) ??
              _cleanExtractedName(record.diagnosis, record.originalFileName) ??
              l10n.sharedPrescription)
        : (_cleanExtractedName(record.diagnosis, record.originalFileName) ??
              _cleanExtractedName(record.title, record.originalFileName) ??
              (record.items.isNotEmpty ? _cleanExtractedName(record.items.first, record.originalFileName) : null) ??
              l10n.sharedPrescription);
    final patient = CheckSummary.cleanPatientName(record.patientName ?? '');
    final hospital = _cleanExtractedName(record.hospitalName, record.originalFileName);
    final source = isTyped ? l10n.sharedTypedByYou : (patient.isNotEmpty ? l10n.sharedForPatient(patient) : hospital ?? '');
    final timestamp = switch ((record.createdAt, record.visitDate ?? record.treatmentDate)) {
      (final savedAt?, _) => formatActivityTimestamp(savedAt, now: now, l10n: l10n),
      (null, final visitDate?) => formatActivityDate(visitDate, now: now, l10n: l10n),
      _ => null,
    };
    return DocumentSummary._(
      DocumentCardType.prescription,
      title,
      source,
      _state(record.processingStatus),
      timestamp: timestamp,
    );
  }

  factory DocumentSummary.policy(Policy record, {DateTime? now, AppLocalizations? l10n}) {
    l10n ??= lookupAppLocalizations(const Locale('en'));
    final insurer = _cleanExtractedName(record.insuranceCompany, record.originalFileName);
    // Phase F §0.3: show extracted product name only — never the filename.
    final title = _cleanExtractedName(record.policyName, record.originalFileName) ?? insurer ?? l10n.sharedPolicy;
    final today = now ?? DateTime.now();
    final end = record.policyEndDate?.toLocal();
    final expired =
        record.status.trim().toLowerCase() == 'expired' ||
        (end != null && DateTime(end.year, end.month, end.day).isBefore(DateTime(today.year, today.month, today.day)));
    final amount = record.coverageAmount;
    final cover = amount != null && amount.isFinite && amount > 0
        ? localizedIndianNumber(l10n).format(amount)
        : null;
    final meta = expired && end != null
        ? l10n.sharedEnded(formatLocalizedDate(l10n, end))
        : [
            if (insurer != null && insurer != title) insurer,
            if (cover != null) l10n.sharedCoverageAmount(cover) else if (end != null) _relativeDate(l10n, end, today),
          ].join(' · ');
    return DocumentSummary._(DocumentCardType.policy, title, meta, _state(record.processingStatus, expired: expired));
  }

  static String _relativeDate(AppLocalizations l10n, DateTime date, DateTime today) {
    if (l10n.localeName == 'en') return CheckSummary.relativeDate(date, today);
    final days = DateTime.utc(today.year, today.month, today.day)
        .difference(DateTime.utc(date.year, date.month, date.day)).inDays;
    return switch (days) {
      0 => l10n.sharedToday,
      1 => l10n.sharedYesterday,
      _ => formatLocalizedDate(l10n, date),
    };
  }

  final DocumentCardType type;
  final String title;
  final String meta;
  final AppDocumentState state;
  final String? timestamp;

  static final _fileExtension = RegExp(r'\.(pdf|jpe?g|png|docx?|webp|heic|txt)$', caseSensitive: false);

  static String? _provided(String? value) {
    final text = value?.trim();
    const placeholders = {'', 'unknown', 'null', 'none', 'n/a', 'not specified', 'uploaded policy'};
    return text == null || placeholders.contains(text.toLowerCase()) ? null : text;
  }

  static String? _cleanExtractedName(String? value, String? originalFileName) {
    final text = _provided(value);
    if (text == null) return null;
    if (_fileExtension.hasMatch(text)) return null;
    final orig = originalFileName?.trim();
    if (orig != null && orig.isNotEmpty && text.toLowerCase() == orig.toLowerCase()) return null;
    return text;
  }

  static String? _firstLine(String? text) {
    final lines = text?.trim().split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty);
    final line = lines?.firstOrNull;
    return (line == null || line.isEmpty) ? null : line;
  }

  static AppDocumentState _state(String? value, {bool expired = false}) {
    switch (value?.trim().toLowerCase()) {
      case null:
      case '':
      case 'completed':
        return expired ? AppDocumentState.expired : AppDocumentState.ready;
      case 'pending':
      case 'processing':
        return AppDocumentState.reading;
      case 'failed':
        return AppDocumentState.failed;
      default:
        debugPrint('[DocumentSummary] Unrecognised processing status: "$value"');
        return expired ? AppDocumentState.expired : AppDocumentState.unknown;
    }
  }
}
