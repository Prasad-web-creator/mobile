import 'package:claimsupport/features/documents/data/document_fields.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart';
import 'package:claimsupport/core/localization/localization.dart';
import 'package:claimsupport/core/localization/translation_mapper.dart';

List<(String, String)> policyDetailFields(Policy policy, {AppLocalizations? l10n}) {
  l10n ??= lookupAppLocalizations(const Locale('en'));
  String date(DateTime value) => formatLocalizedDate(l10n!, value);
  final start = policy.policyStartDate;
  final end = policy.policyEndDate;
  final amount = policy.coverageAmount;
  final period = policy.policyPeriod;
  return [
    if (documentText(policy.insuranceCompany) case final insurer?) (l10n.sharedInsurer, insurer),
    if (documentText(policy.policyNumber) case final number?) (l10n.sharedPolicyNumber, number),
    if (start != null && end != null)
      (l10n.sharedPolicyPeriod, '${date(start)} – ${date(end)}')
    else if (period != null)
      (l10n.sharedPolicyPeriod, period)
    else if (start != null)
      (l10n.sharedStartDate, date(start))
    else if (end != null)
      (l10n.sharedPolicyPeriod, l10n.sharedEnds(date(end)))
    else if (policy.inceptionDate case final inception?)
      (l10n.sharedStartDate, date(inception)),
    if (amount != null && amount.isFinite && amount > 0)
      (
        l10n.sharedSumInsured,
        NumberFormat.currency(locale: l10n.localeName == 'ta' ? 'ta_IN' : 'en_IN', symbol: '₹', decimalDigits: amount % 1 == 0 ? 0 : 2).format(amount),
      ),
    if (policy.renewalDate case final renewal?)
      (l10n.sharedRenewalDate, date(renewal))
    else if (policy.isRenewal case final renewed?)
      (l10n.sharedRenewal, renewed ? l10n.sharedYes : l10n.sharedNo),
    if (policy.continuousRenewal case final continuous?) (l10n.sharedContinuity, continuous ? l10n.sharedYes : l10n.sharedNo),
  ];
}

List<(String, String)> prescriptionDetailFields(Prescription prescription, {AppLocalizations? l10n}) {
  l10n ??= lookupAppLocalizations(const Locale('en'));
  return [
  if (documentText(prescription.doctorName) case final doctor?) (l10n.sharedDoctor, doctor),
  if (documentText(prescription.patientName) case final patient?) (l10n.sharedPatient, patient),
  if (prescription.visitDate case final date?)
    (l10n.sharedVisitDate, formatLocalizedDate(l10n, date))
  else if (prescription.treatmentDate case final date?)
    (l10n.sharedTreatmentDate, formatLocalizedDate(l10n, date)),
  ];
}
