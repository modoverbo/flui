import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/profile/data/fake_account_deletion_repository.dart';
import 'package:flui/features/profile/presentation/providers/account_deletion_controller.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete() succeeds and clears the in-flight state', () async {
    final repository = FakeAccountDeletionRepository();
    final container = ProviderContainer(
      overrides: [
        accountDeletionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(accountDeletionControllerProvider.notifier)
        .delete();

    expect(result, isA<Ok<void>>());
    expect(container.read(accountDeletionControllerProvider), isFalse);
    expect(repository.callCount, 1);
  });

  test('delete() surfaces the repository failure', () async {
    final repository = FakeAccountDeletionRepository()
      ..nextFailure = const AccountDeletionFailure(
        AccountDeletionErrorCode.membershipNotFound,
      );
    final container = ProviderContainer(
      overrides: [
        accountDeletionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(accountDeletionControllerProvider.notifier)
        .delete();

    expect(
      result?.failureOrNull,
      const AccountDeletionFailure(AccountDeletionErrorCode.membershipNotFound),
    );
  });

  test(
    'a second delete() landing while the first is in flight is ignored: '
    'the repository is called exactly once (idempotent double tap)',
    () async {
      final repository = FakeAccountDeletionRepository(
        latency: const Duration(milliseconds: 50),
      );
      final container = ProviderContainer(
        overrides: [
          accountDeletionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        accountDeletionControllerProvider.notifier,
      );

      final first = notifier.delete();
      // Landed before the first call resolves: `state` is already `true`.
      final second = await notifier.delete();
      final firstResult = await first;

      expect(second, isNull);
      expect(firstResult, isA<Ok<void>>());
      expect(repository.callCount, 1);
    },
  );
}
