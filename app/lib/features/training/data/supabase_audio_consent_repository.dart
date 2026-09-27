import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/features/training/domain/audio_consent_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in user's `profiles.audio_retention_consent` (design part-3
/// §5), the only column of `profiles` this repository is granted to touch.
final class SupabaseAudioConsentRepository implements AudioConsentRepository {
  const new(this._client, {required this.currentUserId});

  final SupabaseClient _client;
  final String? Function() currentUserId;

  @override
  Future<Result<bool?>> read() async {
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    try {
      final row = await _client
          .from('profiles')
          .select('audio_retention_consent')
          .eq('id', userId)
          .single();
      return Result.ok(row['audio_retention_consent'] as bool?);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<void>> write({required bool granted}) async {
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    try {
      await _client
          .from('profiles')
          .update({'audio_retention_consent': granted})
          .eq('id', userId);
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
