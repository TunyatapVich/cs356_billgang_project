import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'profile_service.dart';

class ProfileNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateProfile({
    String? displayName,
    String? promptpayNumber,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(profileServiceProvider).updateProfile(
        displayName: displayName,
        promptpayNumber: promptpayNumber,
      );
      await ref.read(authProvider.notifier).refresh();
    });
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, void>(
  ProfileNotifier.new,
);
