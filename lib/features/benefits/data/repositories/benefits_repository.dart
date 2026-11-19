import 'package:dio/dio.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/benefits/data/models/policy_benefits.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/core/models/pagination_response.dart';

/// Read-only access for the My Benefits tab. Uses the existing policy list API
/// and a lightweight benefits endpoint over stored data (no AI processing).
class BenefitsRepository {
  final Dio _dio = ApiClient().dio;

  /// The signed-in user's policies (the API scopes results to the user), keeping
  /// only those with stored benefit details in [BenefitsPolicyList.ready].
  Future<BenefitsPolicyList> getAllPolicies() async {
    final ready = <Policy>[];
    var total = 0;
    var page = 1;
    try {
      while (true) {
        final response = await _dio.get('/policies', queryParameters: {'page': page, 'limit': 100});
        final result = PaginationResponse.fromJson(
          response.data,
          (json) => (policy: Policy.fromJson(json), hasDetails: policyHasBenefitDetails(json)),
        );
        total += result.docs.length;
        ready.addAll(result.docs.where((d) => d.hasDetails).map((d) => d.policy));
        if (!result.hasNextPage || page >= 20) break;
        page++;
      }
      return BenefitsPolicyList(ready: ready, total: total);
    } on DioException catch (e, st) {
      throw _wrap(e, st);
    }
  }

  Future<PolicyBenefits> getBenefits(String policyId) async {
    try {
      final response = await _dio.get('/policies/$policyId/benefits');
      return PolicyBenefits.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e, st) {
      throw _wrap(e, st);
    }
  }

  AppException _wrap(DioException e, StackTrace st) {
    final data = e.response?.data;
    final message = data is Map ? (data['message'] ?? data['detail'])?.toString() : null;
    return AppException(
      statusCode: e.response?.statusCode,
      message: message ?? e.message ?? 'Unknown error',
      responseBody: data,
      originalException: e,
      stackTrace: st,
    );
  }
}
