import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/benefits/data/models/policy_benefits.dart';
import 'package:claimsupport/features/benefits/data/repositories/benefits_repository.dart';

final benefitsRepositoryProvider = Provider((ref) => BenefitsRepository());

/// The signed-in user's policies for the picker (only those with benefit details are selectable).
final benefitsPoliciesProvider = FutureProvider.autoDispose<BenefitsPolicyList>((ref) {
  return ref.watch(benefitsRepositoryProvider).getAllPolicies();
});

/// Benefits of one policy. Keyed by policy id, so switching policies never
/// shows data from the previously selected one.
final policyBenefitsProvider = FutureProvider.autoDispose.family<PolicyBenefits, String>((ref, policyId) {
  return ref.watch(benefitsRepositoryProvider).getBenefits(policyId);
});
