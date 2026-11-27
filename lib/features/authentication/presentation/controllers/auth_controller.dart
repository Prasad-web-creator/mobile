import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    return _fetchUser();
  }

  Future<User?> _fetchUser() async {
    final repository = ref.read(authRepositoryProvider);
    final user = await repository.getMe();
    return user;
  }

  Future<void> updateProfile(String name, String email) async {
    final hasAccount = state.value != null;
    final activeRef = ref;
    if (!hasAccount) state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final updatedUser = await repository.updateProfile(name, email);
      if (activeRef.mounted) state = AsyncData(updatedUser);
    } catch (err, stack) {
      if (activeRef.mounted && !hasAccount) state = AsyncError(err, stack);
      rethrow;
    }
  }
}
