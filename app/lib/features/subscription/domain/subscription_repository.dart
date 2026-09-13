import 'package:flui/core/error/result.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';

abstract interface class SubscriptionRepository {
  /// Active plans ordered for display.
  Future<Result<List<SubscriptionPlan>>> fetchPlans();

  /// Access of the signed-in user (`my_access()`).
  Future<Result<AccessStatus>> fetchAccess();

  /// Creates a hosted checkout for [planId] and returns its purchase URL.
  Future<Result<Uri>> createCheckout({required String planId});
}
