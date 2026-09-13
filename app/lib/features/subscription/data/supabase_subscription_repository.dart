import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/subscription/data/dtos/access_status_dto.dart';
import 'package:flui/features/subscription/data/dtos/subscription_plan_dto.dart';
import 'package:flui/features/subscription/data/subscription_error_mapper.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:flui/features/subscription/domain/subscription_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Plans (PostgREST), access (`my_access()` RPC) and checkout
/// (`whop-checkout` Edge Function).
final class SupabaseSubscriptionRepository implements SubscriptionRepository {
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<SubscriptionPlan>>> fetchPlans() async {
    try {
      // RLS only exposes active plans; the filter keeps intent explicit.
      final rows = await _client
          .from('subscription_plans')
          .select(SubscriptionPlanDto.columns)
          .eq('active', true)
          .order('sort_order');
      return Result.ok([
        for (final row in rows) SubscriptionPlanDto.fromJson(row).toDomain(),
      ]);
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<AccessStatus>> fetchAccess() async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>('my_access');
      return Result.ok(AccessStatusDto.fromJson(json).toDomain());
    } on Object catch (error) {
      return Result.err(mapDataError(error));
    }
  }

  @override
  Future<Result<Uri>> createCheckout({required String planId}) async {
    try {
      final response = await _client.functions.invoke(
        'whop-checkout',
        body: {'planId': planId},
      );
      final url = switch (response.data) {
        {'purchaseUrl': final String raw} => Uri.tryParse(raw),
        _ => null,
      };
      if (url == null || url.scheme != 'https') {
        return const Result.err(
          SubscriptionFailure(SubscriptionErrorCode.checkoutUnavailable),
        );
      }
      return Result.ok(url);
    } on Object catch (error) {
      return Result.err(mapCheckoutError(error));
    }
  }
}
