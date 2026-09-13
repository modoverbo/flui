import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sign_out_controller.g.dart';

/// `true` while signing out. The router reacts to the auth stream.
@riverpod
class SignOutController extends _$SignOutController {
  @override
  bool build() => false;

  Future<void> signOut() async {
    if (state) return;
    state = true;
    await ref.read(authRepositoryProvider).signOut();
    if (!ref.mounted) return;
    state = false;
  }
}
