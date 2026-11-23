import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/network/api_client.dart';

/// Help & Support email, served by the backend from its `SUPPORT_EMAIL` env var
/// (GET /api/app-config), so local and production can differ without an app release.
/// Resolves to null when the backend has no value configured.
final supportEmailProvider = FutureProvider<String?>((ref) async {
  final response = await ApiClient().dio.get('/app-config');
  final data = response.data is Map ? response.data as Map : const {};
  final email = (data['supportEmail'] as String?)?.trim();
  return (email == null || email.isEmpty) ? null : email;
});
