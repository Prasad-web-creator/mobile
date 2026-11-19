/// Plain-language benefits for one policy, as returned by
/// `GET /policies/{id}/benefits`. Everything here comes from the policy data
/// already stored on the server — nothing is computed by AI on the device.
library;

import 'package:claimsupport/features/policies/data/models/policy.dart';

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
}

List<String> _strList(dynamic v) => v is List ? v.map(_str).whereType<String>().toList() : const <String>[];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _mapList(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

DateTime? _date(dynamic v) {
  final s = _str(v);
  if (s == null) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

enum PolicyValidity { active, expired, upcoming, unknown }

/// Fields whose presence means the policy's benefits were read from the document.
/// Mirrors `has_details` in backend `services/benefits/policy_benefits.py`.
const _benefitDetailKeys = [
  'coverageAmount',
  'coPay',
  'roomEligibility',
  'waitingPeriodDays',
  'preExistingDiseases',
  'preHospitalizationDays',
  'subLimits',
  'specialConditions',
  'coveredTreatments',
];

/// Whether a raw policy record (from `GET /policies`) has enough stored data
/// to show on My Benefits. An empty skeleton of lists does not count.
bool policyHasBenefitDetails(Map<String, dynamic> policyJson) {
  final extracted = policyJson['extractedPolicyJson'];
  if (extracted is! Map) return false;
  for (final key in _benefitDetailKeys) {
    final v = extracted[key];
    if (v == null) continue;
    if (v is String && (v.trim().isEmpty || v.trim().toLowerCase() == 'null')) continue;
    if (v is Iterable && v.isEmpty) continue;
    if (v is Map && v.isEmpty) continue;
    return true;
  }
  return false;
}

/// The user's policies for the My Benefits picker.
class BenefitsPolicyList {
  /// Policies with stored benefit details (shown in the dropdown).
  final List<Policy> ready;

  /// Every policy the user has, including ones not read yet.
  final int total;

  const BenefitsPolicyList({required this.ready, required this.total});
}

class SourceReference {
  final String? clause;
  final String? page;
  final String? text;

  const SourceReference({this.clause, this.page, this.text});

  static SourceReference? fromJson(dynamic json) {
    final m = _map(json);
    final r = SourceReference(clause: _str(m['clause']), page: _str(m['page']), text: _str(m['text']));
    return (r.clause ?? r.page ?? r.text) == null ? null : r;
  }
}

/// One benefit / limit / condition line.
class BenefitItem {
  final String key;
  final String title;
  final String? value;
  final String? description;
  final List<String> conditions;
  final String? wording;
  final SourceReference? reference;
  final bool available;

  const BenefitItem({
    required this.key,
    required this.title,
    this.value,
    this.description,
    this.conditions = const [],
    this.wording,
    this.reference,
    this.available = true,
  });

  bool get hasDetails => wording != null || conditions.isNotEmpty || reference != null;

  factory BenefitItem.fromJson(Map<String, dynamic> j) => BenefitItem(
    key: _str(j['key']) ?? '',
    title: _str(j['title']) ?? '',
    value: _str(j['value']),
    description: _str(j['description']),
    conditions: _strList(j['conditions']),
    wording: _str(j['wording']),
    reference: SourceReference.fromJson(j['reference']),
    available: j['available'] != false,
  );
}

class WaitingPeriod {
  final String key;
  final String title;
  final String? duration;
  final String? description;
  final DateTime? endDate;
  final String? wording;
  final SourceReference? reference;
  final List<String> conditions;

  const WaitingPeriod({
    required this.key,
    required this.title,
    this.duration,
    this.description,
    this.endDate,
    this.wording,
    this.reference,
    this.conditions = const [],
  });

  /// Whether the calculated end date has passed (null when it can't be calculated).
  bool? get isOver {
    if (endDate == null) return null;
    final now = DateTime.now();
    return !endDate!.isAfter(DateTime(now.year, now.month, now.day));
  }

  factory WaitingPeriod.fromJson(Map<String, dynamic> j) => WaitingPeriod(
    key: _str(j['key']) ?? '',
    title: _str(j['title']) ?? 'Waiting period',
    duration: _str(j['duration']),
    description: _str(j['description']),
    endDate: _date(j['endDate']),
    wording: _str(j['wording']),
    reference: SourceReference.fromJson(j['reference']),
    conditions: _strList(j['conditions']),
  );
}

class PolicyOverview {
  final String? policyName;
  final String? insuranceCompany;
  final String? policyNumber;
  final String? policyHolderName;
  final String? policyType;
  final DateTime? startDate;
  final DateTime? endDate;

  const PolicyOverview({
    this.policyName,
    this.insuranceCompany,
    this.policyNumber,
    this.policyHolderName,
    this.policyType,
    this.startDate,
    this.endDate,
  });

  /// Validity from the stored dates and today's date on the device.
  PolicyValidity get validity {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (startDate == null && endDate == null) return PolicyValidity.unknown;
    if (startDate != null && startDate!.isAfter(today)) return PolicyValidity.upcoming;
    if (endDate != null && endDate!.isBefore(today)) return PolicyValidity.expired;
    return endDate != null ? PolicyValidity.active : PolicyValidity.unknown;
  }

  factory PolicyOverview.fromJson(Map<String, dynamic> j) => PolicyOverview(
    policyName: _str(j['policyName']),
    insuranceCompany: _str(j['insuranceCompany']),
    policyNumber: _str(j['policyNumber']),
    policyHolderName: _str(j['policyHolderName']),
    policyType: _str(j['policyType']),
    startDate: _date(j['startDate']),
    endDate: _date(j['endDate']),
  );
}

class PolicyBenefits {
  final String policyId;
  final PolicyOverview overview;
  final bool hasDetails;

  final double? sumInsured;
  final BenefitItem sumInsuredItem;
  final BenefitItem coPayment;
  final BenefitItem deductible;

  final List<WaitingPeriod> waitingPeriods;
  final DateTime? waitingStartDate;
  final String? waitingBasis;
  final List<String> waitingNotes;

  final BenefitItem? roomRent;
  final List<BenefitItem> limits;
  final List<BenefitItem> additionalBenefits;

  final List<String> specialConditions;
  final List<String> exclusions;
  final List<String> nonPayableItems;

  const PolicyBenefits({
    required this.policyId,
    required this.overview,
    required this.hasDetails,
    required this.sumInsured,
    required this.sumInsuredItem,
    required this.coPayment,
    required this.deductible,
    required this.waitingPeriods,
    required this.waitingStartDate,
    required this.waitingBasis,
    required this.waitingNotes,
    required this.roomRent,
    required this.limits,
    required this.additionalBenefits,
    required this.specialConditions,
    required this.exclusions,
    required this.nonPayableItems,
  });

  factory PolicyBenefits.fromJson(Map<String, dynamic> j) {
    final key = _map(j['keyBenefits']);
    final si = _map(key['sumInsured']);
    final wp = _map(j['waitingPeriods']);
    final cond = _map(j['conditions']);
    final room = j['roomRent'];
    final amount = si['amount'];

    BenefitItem item(dynamic v, String k, String title) {
      final m = _map(v);
      return m.isEmpty ? BenefitItem(key: k, title: title, available: false) : BenefitItem.fromJson(m);
    }

    return PolicyBenefits(
      policyId: _str(j['policyId']) ?? '',
      overview: PolicyOverview.fromJson(_map(j['overview'])),
      hasDetails: j['hasDetails'] == true,
      sumInsured: amount is num && amount > 0 ? amount.toDouble() : null,
      sumInsuredItem: item(si, 'sumInsured', 'Sum Insured'),
      coPayment: item(key['coPayment'], 'coPayment', 'Co-payment'),
      deductible: item(key['deductible'], 'deductible', 'Deductible'),
      waitingPeriods: _mapList(wp['periods']).map(WaitingPeriod.fromJson).toList(),
      waitingStartDate: _date(wp['startDate']),
      waitingBasis: _str(wp['basis']),
      waitingNotes: _strList(wp['notes']),
      roomRent: room is Map ? BenefitItem.fromJson(Map<String, dynamic>.from(room)) : null,
      limits: _mapList(j['limits']).map(BenefitItem.fromJson).toList(),
      additionalBenefits: _mapList(j['additionalBenefits']).map(BenefitItem.fromJson).toList(),
      specialConditions: _strList(cond['special']),
      exclusions: _strList(cond['exclusions']),
      nonPayableItems: _strList(cond['nonPayableItems']),
    );
  }
}
