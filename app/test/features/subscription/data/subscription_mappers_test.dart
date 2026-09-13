import 'package:flui/core/error/failure.dart';
import 'package:flui/features/subscription/data/dtos/access_status_dto.dart';
import 'package:flui/features/subscription/data/dtos/subscription_plan_dto.dart';
import 'package:flui/features/subscription/data/subscription_error_mapper.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SubscriptionPlanDto', () {
    test('maps a subscription_plans row', () {
      final dto = SubscriptionPlanDto.fromJson(const {
        'id': 'quarterly',
        'billing_period_days': 90,
        'price_cents': 2499,
        'currency': 'USD',
        'label': 'Trimestral',
        'savings_label': 'Ahorra 17%',
        'sort_order': 2,
      });

      expect(
        dto.toDomain(),
        const SubscriptionPlan(
          id: 'quarterly',
          billingPeriodDays: 90,
          priceCents: 2499,
          currency: 'USD',
          label: 'Trimestral',
          savingsLabel: 'Ahorra 17%',
          sortOrder: 2,
        ),
      );
    });
  });

  group('AccessStatusDto', () {
    test('maps my_access() while trialing', () {
      final dto = AccessStatusDto.fromJson(const {
        'has_access': true,
        'entitlement_status': 'trialing',
        'current_period_end': '2026-09-20T10:00:00+00:00',
        'trial_ends_at': '2026-09-20T10:00:00+00:00',
      });

      final status = dto.toDomain();
      expect(status.hasAccess, isTrue);
      expect(status.entitlementStatus, EntitlementStatus.trialing);
      expect(status.trialEndsAt, DateTime.utc(2026, 9, 20, 10));
      expect(status.currentPeriodEnd, DateTime.utc(2026, 9, 20, 10));
    });

    test('maps my_access() without an entitlement', () {
      final dto = AccessStatusDto.fromJson(const {
        'has_access': false,
        'entitlement_status': null,
        'current_period_end': null,
        'trial_ends_at': null,
      });

      expect(dto.toDomain(), AccessStatus.none);
    });

    test('maps every entitlement status and ignores unknown ones', () {
      AccessStatus map(String status) => AccessStatusDto.fromJson({
        'has_access': false,
        'entitlement_status': status,
      }).toDomain();

      expect(map('active').entitlementStatus, EntitlementStatus.active);
      expect(map('past_due').entitlementStatus, EntitlementStatus.pastDue);
      expect(map('canceled').entitlementStatus, EntitlementStatus.canceled);
      expect(map('expired').entitlementStatus, EntitlementStatus.expired);
      expect(map('paused').entitlementStatus, isNull);
    });
  });

  group('mapCheckoutError', () {
    Failure functionError(int status, [String? code]) => mapCheckoutError(
      FunctionException(
        status: status,
        details: code == null
            ? null
            : {
                'error': {'code': code, 'message': 'x'},
              },
      ),
    );

    test('409 already_subscribed', () {
      expect(
        functionError(409, 'already_subscribed'),
        const SubscriptionFailure(SubscriptionErrorCode.alreadySubscribed),
      );
      expect(
        functionError(409),
        const SubscriptionFailure(SubscriptionErrorCode.alreadySubscribed),
      );
    });

    test('404 unknown_plan and 401 unauthorized', () {
      expect(
        functionError(404, 'unknown_plan'),
        const SubscriptionFailure(SubscriptionErrorCode.unknownPlan),
      );
      expect(
        functionError(401, 'unauthorized'),
        const SubscriptionFailure(SubscriptionErrorCode.unauthorized),
      );
    });

    test('upstream and server errors mean checkout is unavailable', () {
      for (final status in [502, 500, 503]) {
        expect(
          functionError(status),
          const SubscriptionFailure(SubscriptionErrorCode.checkoutUnavailable),
        );
      }
    });

    test('other client errors are unknown subscription failures', () {
      expect(
        functionError(403, 'origin_not_allowed'),
        const SubscriptionFailure(SubscriptionErrorCode.unknown),
      );
    });

    test('transport errors are network failures', () {
      expect(
        mapCheckoutError(const FunctionsFetchException(details: 'offline')),
        const NetworkFailure(),
      );
      expect(
        mapCheckoutError(http.ClientException('x')),
        const NetworkFailure(),
      );
    });
  });

  group('mapDataError', () {
    test('transport errors are network failures, others unexpected', () {
      expect(mapDataError(http.ClientException('x')), const NetworkFailure());
      const error = PostgrestException(message: 'denied', code: '42501');
      expect(mapDataError(error), const UnexpectedFailure(error));
    });
  });
}
