import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:claimsupport/core/design/widgets/app_document_row.dart';
import 'package:claimsupport/core/design/widgets/document_card.dart';
import 'package:claimsupport/core/utils/activity_timestamp.dart';
import 'package:claimsupport/features/home/data/check_summary.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';

@immutable
class DocumentSummary {
  const DocumentSummary._(this.type, this.title, this.meta, this.state, {this.timestamp});

  factory DocumentSummary.prescription(Prescription record, {DateTime? now}) {
    final isTyped = record.isManual;
    final title = isTyped
        ? (_firstLine(record.manualText ?? record.extractedPrescriptionText) ??
              _cleanExtractedName(record.diagnosis, record.originalFileName) ??
              'Prescription')
        : (_cleanExtractedName(record.diagnosis, record.originalFileName) ??
              _cleanExtractedName(record.title, record.originalFileName) ??
              (record.items.isNotEmpty ? _cleanExtractedName(record.items.first, record.originalFileName) : null) ??
              'Prescription');
    final patient = CheckSummary.cleanPatientName(record.patientName ?? '');
    final hospital = _cleanExtractedName(record.hospitalName, record.originalFileName);
    final source = isTyped ? 'Typed by you' : (patient.isNotEmpty ? 'For $patient' : hospital ?? '');
    final timestamp = switch ((record.createdAt, record.visitDate ?? record.treatmentDate)) {
      (final savedAt?, _) => formatActivityTimestamp(savedAt, now: now),
      (null, final visitDate?) => formatActivityDate(visitDate, now: now),
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

  factory DocumentSummary.policy(Policy record, {DateTime? now}) {
    final insurer = _cleanExtractedName(record.insuranceCompany, record.originalFileName);
    // Phase F §0.3: show extracted product name only — never the filename.
    final title = _cleanExtractedName(record.policyName, record.originalFileName) ?? insurer ?? 'Policy';
    final today = now ?? DateTime.now();
    final end = record.policyEndDate?.toLocal();
    final expired =
        record.status.trim().toLowerCase() == 'expired' ||
        (end != null && DateTime(end.year, end.month, end.day).isBefore(DateTime(today.year, today.month, today.day)));
    final amount = record.coverageAmount;
    final cover = amount != null && amount.isFinite && amount > 0
        ? NumberFormat.decimalPattern('en_IN').format(amount)
        : null;
    final meta = expired && end != null
        ? 'Ended ${DateFormat('d MMM yyyy').format(end)}'
        : [
            if (insurer != null && insurer != title) insurer,
            if (cover != null) '₹$cover cover' else if (end != null) CheckSummary.relativeDate(end, today),
          ].join(' · ');
    return DocumentSummary._(DocumentCardType.policy, title, meta, _state(record.processingStatus, expired: expired));
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
