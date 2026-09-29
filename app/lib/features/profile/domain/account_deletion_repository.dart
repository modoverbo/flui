import 'package:flui/core/error/result.dart';

/// Deletes the signed-in user's own account (U22e, decision #434).
///
/// The server (`supabase/functions/account-delete/`) cancels any live Whop
/// membership at period end, wipes every stored recording, then deletes the
/// auth user — in that order, failing closed at the first step that does
/// not succeed (see ADR-0004 decision 9). This port only exposes the single
/// outcome; the ordering and safety contract live server-side.
abstract interface class AccountDeletionRepository {
  Future<Result<void>> deleteAccount();
}
