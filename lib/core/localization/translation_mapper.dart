import 'package:intl/intl.dart';

import 'localization.dart';

String localizedCheckStatus(AppLocalizations l10n, String raw) {
  if (l10n.localeName != 'ta') return raw;
  final normalized = raw
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('’', "'");
  return switch (normalized) {
    'covered' || 'approved' || 'likely covered' => l10n.sharedCovered,
    'fully covered' => l10n.sharedFullyCovered,
    'partially covered' || 'partial' || 'partially' => l10n.sharedPartial,
    'not covered' || 'rejected' => l10n.sharedNotCovered,
    'needs verification' => l10n.sharedVerification,
    'needs info' ||
    'needs your input' ||
    'waiting for user' => l10n.sharedNeedsInfo,
    'needs review' || 'manual review required' => l10n.sharedNeedsReview,
    'invalid policy' => l10n.sharedInvalidPolicy,
    'invalid prescription' ||
    'not a prescription' => l10n.sharedInvalidPrescription,
    'invalid' ||
    'invalid policy and prescription' => l10n.sharedInvalidDocument,
    'checking…' ||
    'checking' ||
    'running' ||
    'processing' ||
    'analyzing' ||
    'extracting' ||
    'reanalyzing' ||
    'extracting documents' ||
    'extracting policy metadata' => l10n.sharedChecking,
    'pending' || 'queued' => l10n.sharedPending,
    'completed' || 'complete' => l10n.sharedCompleted,
    'failed' || 'check failed' => l10n.sharedFailed,
    "couldn't check" => l10n.sharedCouldNotCheck,
    "couldn't read" => l10n.sharedCouldNotRead,
    'cancelled' || 'canceled' || 'check cancelled' => l10n.sharedCancelled,
    'expired' => l10n.sharedExpired,
    '' => '',
    _ =>
      RegExp(r'[\u0B80-\u0BFF]').hasMatch(raw) ? raw : l10n.sharedUnavailable,
  };
}

String localizedPolicyType(AppLocalizations l10n, String raw) {
  if (l10n.localeName != 'ta') return raw;
  return switch (raw.trim().toLowerCase().replaceAll(RegExp(r'[_-]'), ' ')) {
    'individual' || 'individual policy' => l10n.sharedIndividual,
    'family' || 'family policy' => l10n.sharedFamily,
    'family floater' || 'floater' => l10n.sharedFamilyFloater,
    'group' || 'group policy' => l10n.sharedGroup,
    'renewed' || 'renewal' => l10n.sharedRenewed,
    'new' || 'new policy' => l10n.sharedNewFirstYear,
    '' => '',
    _ => RegExp(r'[\u0B80-\u0BFF]').hasMatch(raw) ? raw : l10n.sharedUnknown,
  };
}

String localizedItemType(AppLocalizations l10n, String raw) {
  if (l10n.localeName != 'ta') return raw;
  return switch (raw.trim().toLowerCase()) {
    'diagnosis' => l10n.analysisItemDiagnosis,
    'test' || 'diagnostic test' || 'investigation' => l10n.analysisItemTest,
    'procedure' || 'surgery' => l10n.analysisItemProcedure,
    'medicine' || 'medication' || 'drug' => l10n.analysisItemMedicine,
    'consultation' || 'visit' => l10n.analysisItemConsultation,
    'symptom' => l10n.analysisItemSymptom,
    'treatment' => l10n.sharedTreatment,
    _ => l10n.analysisTreatmentItem,
  };
}

String dateFormatLocale(String? language) => language == 'ta' ? 'ta' : 'en_US';

String formatLocalizedDate(
  AppLocalizations l10n,
  DateTime date, {
  String pattern = 'd MMM yyyy',
}) => DateFormat(pattern, dateFormatLocale(l10n.localeName)).format(date);

NumberFormat localizedIndianNumber(AppLocalizations l10n) =>
    NumberFormat.decimalPattern(l10n.localeName == 'ta' ? 'ta_IN' : 'en_IN');
