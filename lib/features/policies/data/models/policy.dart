import 'package:claimsupport/features/documents/data/document_fields.dart';

class Policy {
  final String id;
  final String policyNumber;
  final String policyName;
  final String? policyHolderName;
  final String insuranceCompany;
  final String? policyType;
  final DateTime? policyStartDate;
  final DateTime? policyEndDate;
  final DateTime? inceptionDate;
  final String? policyPeriod;
  final DateTime? renewalDate;
  final bool? isRenewal;
  final bool? continuousRenewal;
  final double? coverageAmount;
  final String status;
  final String? gridFsFileId;
  final String? originalFileName;
  final String? mimeType;
  final int? fileSize;
  final int? sequenceNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? processingStatus;
  final List<String> insuredMembers;

  String get displayId {
    if (sequenceNumber != null) {
      return 'PCY${sequenceNumber.toString().padLeft(4, '0')}';
    }
    return id.isNotEmpty ? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()) : 'PCY';
  }

  Policy({
    required this.id,
    required this.policyNumber,
    required this.policyName,
    this.policyHolderName,
    required this.insuranceCompany,
    this.policyType,
    this.policyStartDate,
    this.policyEndDate,
    this.inceptionDate,
    this.policyPeriod,
    this.renewalDate,
    this.isRenewal,
    this.continuousRenewal,
    this.coverageAmount,
    required this.status,
    this.gridFsFileId,
    this.originalFileName,
    this.mimeType,
    this.fileSize,
    this.sequenceNumber,
    this.createdAt,
    this.updatedAt,
    this.processingStatus,
    this.insuredMembers = const [],
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val.isUtc ? val.toLocal() : val;
      final str = val.toString().trim();
      if (str.isEmpty || str.toLowerCase() == 'null') return null;

      String parseableStr = str;
      if (str.contains('T') && !str.endsWith('Z') && !str.contains('+')) {
        parseableStr = '${str}Z';
      }

      final dt = DateTime.tryParse(parseableStr) ?? DateTime.tryParse(str);
      if (dt != null) {
        return dt.toLocal();
      }

      final slashParts = str.split('/');
      if (slashParts.length == 3) {
        if (slashParts[0].length == 4) {
          return DateTime.tryParse(
            "${slashParts[0]}-${slashParts[1].padLeft(2, '0')}-${slashParts[2].padLeft(2, '0')}",
          );
        }
        return DateTime.tryParse("${slashParts[2]}-${slashParts[1].padLeft(2, '0')}-${slashParts[0].padLeft(2, '0')}");
      }
      final dashParts = str.split('-');
      if (dashParts.length == 3) {
        if (dashParts[0].length == 4) {
          return DateTime.tryParse("${dashParts[0]}-${dashParts[1].padLeft(2, '0')}-${dashParts[2].padLeft(2, '0')}");
        }
        return DateTime.tryParse("${dashParts[2]}-${dashParts[1].padLeft(2, '0')}-${dashParts[0].padLeft(2, '0')}");
      }
      return null;
    }

    final meta = documentMap(json['metadata']);
    final extracted = documentMap(json['extractedPolicyJson']);
    final continuity = documentMap(extracted['continuity']);
    final period = documentMap(extracted['policyPeriod']);
    final insurer = firstDocumentText([
      json['insuranceCompany'],
      extracted['insuranceCompany'],
      continuity['insuranceCompany'],
      meta['provider_name'],
    ]);
    final rawName = documentText(json['policyName']);
    final policyName = rawName != null && rawName.toLowerCase() != 'uploaded policy'
        ? rawName
        : firstDocumentText([extracted['policyName'], meta['plan_name'], insurer]) ?? '';
    final renewal = firstDocumentBoolean([json['isRenewal'], extracted['isRenewal'], continuity['isRenewal']]);
    final newPolicy = firstDocumentBoolean([json['isNewPolicy'], extracted['isNewPolicy']]);
    final members = {
      for (final source in [json, extracted, meta])
        for (final key in ['insuredMembers', 'coveredMembers', 'members', 'insured_members'])
          ...documentNames(source[key], ['name', 'memberName', 'insuredName', 'insuredPersonName']),
    }.toList();

    return Policy(
      insuredMembers: members,
      processingStatus: json['processingStatus']?.toString(),
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      policyNumber:
          firstDocumentText([
            json['policyNumber'],
            extracted['policyNumber'],
            continuity['policyNumber'],
            meta['policy_number'],
          ]) ??
          '',
      policyName: policyName,
      policyHolderName: firstDocumentText([
        json['policyHolderName'],
        extracted['policyHolderName'],
        extracted['policyHolder'],
        extracted['insuredName'],
        continuity['policyHolder'],
        meta['policy_holder_name'],
        meta['insured_person_name'],
      ]),
      insuranceCompany: insurer ?? '',
      policyType: firstDocumentText([json['policyType'], extracted['policyType'], meta['policy_type']]),
      policyStartDate: firstDocumentDate([
        json['policyStartDate'],
        extracted['policyStartDate'],
        continuity['policyStartDate'],
        extracted['startDate'],
        period['startDate'],
        meta['policy_start_date'],
      ]),
      policyEndDate: firstDocumentDate([
        json['policyEndDate'],
        extracted['policyEndDate'],
        continuity['policyEndDate'],
        extracted['endDate'],
        extracted['expiryDate'],
        period['endDate'],
        meta['policy_expiry_date'],
      ]),
      policyPeriod: firstDocumentText([json['policyPeriod'], extracted['policyPeriod'], meta['policy_period']]),
      inceptionDate: firstDocumentDate([json['inceptionDate'], extracted['inceptionDate']]),
      renewalDate: firstDocumentDate([
        json['renewalDate'],
        extracted['renewalDate'],
        continuity['renewalDate'],
        meta['renewal_date'],
      ]),
      isRenewal: renewal ?? (newPolicy == null ? null : !newPolicy),
      continuousRenewal: firstDocumentBoolean([
        json['continuousRenewal'],
        continuity['renewedWithoutBreak'],
        extracted['renewedWithoutBreak'],
      ]),
      coverageAmount: firstDocumentAmount([
        json['coverageAmount'],
        extracted['coverageAmount'],
        extracted['sumInsured'],
        meta['sum_insured'],
      ]),
      status: json['status'] ?? 'Active',
      gridFsFileId: json['gridFsFileId'],
      originalFileName: json['originalFileName'] ?? meta['original_file_name'],
      mimeType: json['mimeType'],
      fileSize: (json['fileSize'] as num?)?.toInt(),
      sequenceNumber: (json['sequenceNumber'] as num?)?.toInt(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'policyNumber': policyNumber,
      'policyName': policyName,
      'policyHolderName': policyHolderName,
      'insuranceCompany': insuranceCompany,
      'policyType': policyType,
      'policyStartDate': policyStartDate?.toIso8601String(),
      'policyEndDate': policyEndDate?.toIso8601String(),
      'coverageAmount': coverageAmount,
      'status': status,
      'gridFsFileId': gridFsFileId,
      'originalFileName': originalFileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
    };
  }
}
