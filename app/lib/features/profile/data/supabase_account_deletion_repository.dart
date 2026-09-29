import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/features/profile/data/account_deletion_error_mapper.dart';
import 'package:flui/features/profile/domain/account_deletion_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the `account-delete` Edge Function (U22b/U22e, decision #434): POST,
/// bearer auth, no body. Success is `200 {"status": "deleted"}`; failures
/// carry `{"error": {"code", "message"}}`, mapped to a typed
/// [AccountDeletionFailure] the UI can show distinctly from a generic error.
final class SupabaseAccountDeletionRepository
    implements AccountDeletionRepository {
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      final response = await _client.functions.invoke('account-delete');
      final data = response.data;
      if (data is Map && data['status'] == 'deleted') {
        return const Result.ok(null);
      }
      return Result.err(mapAccountDeletionErrorCode(null));
    } on FunctionsFetchException catch (error) {
      // No response reached the client (network/transport failure): keep
      // going through the transport error mapper, same as any other call.
      return Result.err(mapDataError(error));
    } on FunctionException catch (error) {
      return Result.err(
        mapAccountDeletionErrorCode(
          readAccountDeletionErrorCode(error.details),
        ),
      );
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
