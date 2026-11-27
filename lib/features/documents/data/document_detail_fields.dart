import 'package:claimsupport/features/documents/data/document_fields.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:intl/intl.dart';

List<(String, String)> policyDetailFields(Policy policy) {
  final start = policy.policyStartDate;
  final end = policy.policyEndDate;
  final amount = policy.coverageAmount;
  final period = policy.policyPeriod;
  return [
    if (documentText(policy.insuranceCompany) case final insurer?) ('Insurer', insurer),
    if (documentText(policy.policyNumber) case final number?) ('Policy number', number),
    if (start != null && end != null)
      ('Policy period', '${_date(start)} – ${_date(end)}')
    else if (period != null)
      ('Policy period', period)
    else if (start != null)
      ('Start date', _date(start))
    else if (end != null)
      ('Policy period', 'Ends ${_date(end)}')
    else if (policy.inceptionDate case final inception?)
      ('Start date', _date(inception)),
    if (amount != null && amount.isFinite && amount > 0)
      (
        'Sum insured',
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: amount % 1 == 0 ? 0 : 2).format(amount),
      ),
    if (policy.renewalDate case final renewal?)
      ('Renewal date', _date(renewal))
    else if (policy.isRenewal case final renewed?)
      ('Renewal', renewed ? 'Yes' : 'No'),
    if (policy.continuousRenewal case final continuous?) ('Continuity', continuous ? 'Yes' : 'No'),
  ];
}

List<(String, String)> prescriptionDetailFields(Prescription prescription) => [
  if (documentText(prescription.doctorName) case final doctor?) ('Doctor', doctor),
  if (documentText(prescription.patientName) case final patient?) ('Patient', patient),
  if (prescription.visitDate case final date?)
    ('Visit date', _date(date))
  else if (prescription.treatmentDate case final date?)
    ('Treatment date', _date(date)),
];

String _date(DateTime date) => DateFormat('d MMM yyyy', 'en_US').format(date);
