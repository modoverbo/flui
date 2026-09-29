import 'dart:convert';

import 'package:flui/core/error/failure.dart';
import 'package:flui/features/profile/data/fake_account_deletion_repository.dart';
import 'package:flui/features/profile/data/supabase_account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_recorder.dart';

void main() {
  group('FakeAccountDeletionRepository', () {
    test('succeeds by default and records every call', () async {
      final repository = FakeAccountDeletionRepository();

      final result = await repository.deleteAccount();

      expect(result.isOk, isTrue);
      expect(repository.callCount, 1);
    });

    test('returns the injected failure once, then succeeds again', () async {
      final repository = FakeAccountDeletionRepository()
        ..nextFailure = const AccountDeletionFailure(
          AccountDeletionErrorCode.billingUnavailable,
        );

      final first = await repository.deleteAccount();
      final second = await repository.deleteAccount();

      expect(
        first.failureOrNull,
        const AccountDeletionFailure(
          AccountDeletionErrorCode.billingUnavailable,
        ),
      );
      expect(second.isOk, isTrue);
    });
  });

  group('SupabaseAccountDeletionRepository', () {
    test('succeeds on {status: deleted}', () async {
      final recorder = SupabaseRecorder(
        respond: (request) {
          expect(request.url.path, endsWith('/functions/v1/account-delete'));
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({'status': 'deleted'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        },
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseAccountDeletionRepository(recorder.client)
          .deleteAccount();

      expect(result.isOk, isTrue);
    });

    test(
      'an unrecognized success body maps to AccountDeletionFailure.unknown',
      () async {
        final recorder = SupabaseRecorder(
          respond: (request) => http.Response(
            jsonEncode({'ok': true}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(recorder.dispose);

        final result = await SupabaseAccountDeletionRepository(recorder.client)
            .deleteAccount();

        expect(
          result.failureOrNull,
          const AccountDeletionFailure(AccountDeletionErrorCode.unknown),
        );
      },
    );

    for (final testCase in [
      (
        code: 'billing_unavailable',
        status: 503,
        expected: AccountDeletionErrorCode.billingUnavailable,
      ),
      (
        code: 'entitlement_unavailable',
        status: 503,
        expected: AccountDeletionErrorCode.billingUnavailable,
      ),
      (
        code: 'whop_membership_not_found',
        status: 502,
        expected: AccountDeletionErrorCode.membershipNotFound,
      ),
      (
        code: 'membership_id_missing',
        status: 500,
        expected: AccountDeletionErrorCode.membershipNotFound,
      ),
      (
        code: 'storage_cleanup_failed',
        status: 502,
        expected: AccountDeletionErrorCode.deletionFailed,
      ),
      (
        code: 'account_deletion_failed',
        status: 502,
        expected: AccountDeletionErrorCode.deletionFailed,
      ),
      (
        code: 'unauthorized',
        status: 401,
        expected: AccountDeletionErrorCode.unknown,
      ),
      (
        code: 'origin_not_allowed',
        status: 403,
        expected: AccountDeletionErrorCode.unknown,
      ),
    ]) {
      test('maps ${testCase.code} (${testCase.status}) to '
          '${testCase.expected}', () async {
        final recorder = SupabaseRecorder(
          respond: (request) => http.Response(
            jsonEncode({
              'error': {'code': testCase.code, 'message': 'details'},
            }),
            testCase.status,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(recorder.dispose);

        final result = await SupabaseAccountDeletionRepository(recorder.client)
            .deleteAccount();

        expect(result.failureOrNull, AccountDeletionFailure(testCase.expected));
      });
    }

    test(
      'an unrecognized error code maps to AccountDeletionErrorCode.unknown',
      () async {
        final recorder = SupabaseRecorder(
          respond: (request) => http.Response(
            jsonEncode({
              'error': {'code': 'a_brand_new_code', 'message': 'x'},
            }),
            502,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        addTearDown(recorder.dispose);

        final result = await SupabaseAccountDeletionRepository(recorder.client)
            .deleteAccount();

        expect(
          result.failureOrNull,
          const AccountDeletionFailure(AccountDeletionErrorCode.unknown),
        );
      },
    );
  });
}
