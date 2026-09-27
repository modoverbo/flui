import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/supabase/data_error_mapper.dart';
import 'package:flui/core/supabase/paged_query.dart';
import 'package:flui/features/diagnosis/data/dtos/skill_profile_dto.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `public.skill_profiles` of the signed-in user (RLS scopes rows to the
/// owner; the `skill_profiles_before_insert` trigger owns `kind` and
/// `diagnosed_at`, and rejects a too-soon retake).
final class SupabaseSkillProfileRepository implements SkillProfileRepository {
  const new(this._client);

  /// The literal message the server raises for a too-soon retake (design
  /// part-3 §5's `skill_profiles_before_insert`).
  static const _retakeTooSoonMessage = 'retake_too_soon';

  final SupabaseClient _client;

  @override
  Future<Result<SkillProfileRecord?>> latest() async {
    try {
      final row = await _client
          .from('skill_profiles')
          .select(SkillProfileDto.columns)
          .order('diagnosed_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return Result.ok(
        row == null ? null : SkillProfileDto.fromJson(row).toDomain(),
      );
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<List<SkillProfileRecord>>> history() async {
    try {
      final rows = await fetchAllPages(
        (from, to) => _client
            .from('skill_profiles')
            .select(SkillProfileDto.columns)
            .order('diagnosed_at', ascending: false)
            .range(from, to),
      );
      return Result.ok([
        for (final row in rows) SkillProfileDto.fromJson(row).toDomain(),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<SkillProfileRecord>> save({
    required String sessionId,
    required SkillProfile profile,
  }) async {
    try {
      final row = await _client
          .from('skill_profiles')
          .insert(
            SkillProfileDto.forInsert(id: sessionId, profile: profile).toJson(),
          )
          .select(SkillProfileDto.columns)
          .single();
      return Result.ok(SkillProfileDto.fromJson(row).toDomain());
    } on PostgrestException catch (error) {
      if (error.message == _retakeTooSoonMessage) {
        return const Result.err(
          SkillProfileFailure(SkillProfileErrorCode.retakeTooSoon),
        );
      }
      return Result.err(mapDataError(error));
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }
}
