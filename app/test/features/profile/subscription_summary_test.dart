import 'package:flui/core/l10n/gen/app_localizations_es.dart';
import 'package:flui/features/profile/presentation/subscription_summary.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final l10n = AppLocalizationsEs();

  setUpAll(() => initializeDateFormatting('es'));

  test('trialing shows the trial end date', () {
    final status = AccessStatus(
      hasAccess: true,
      entitlementStatus: EntitlementStatus.trialing,
      trialEndsAt: DateTime(2026, 9, 20),
    );

    expect(
      subscriptionSummary(l10n, status),
      'Prueba gratis hasta el 20 de septiembre',
    );
  });

  test('active shows the period end when known', () {
    final status = AccessStatus(
      hasAccess: true,
      entitlementStatus: EntitlementStatus.active,
      currentPeriodEnd: DateTime(2026, 10, 13),
    );

    expect(
      subscriptionSummary(l10n, status),
      'Plan activo hasta el 13 de octubre',
    );
    expect(
      subscriptionSummary(l10n, status.copyWith(currentPeriodEnd: null)),
      'Plan activo',
    );
  });

  test('anything without access is an inactive plan', () {
    expect(subscriptionSummary(l10n, AccessStatus.none), 'Sin plan activo');
    expect(subscriptionSummary(l10n, null), 'Sin plan activo');
  });
}
