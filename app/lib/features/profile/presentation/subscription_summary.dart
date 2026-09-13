import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/features/subscription/domain/access_status.dart';

/// One line describing the user's plan on "Tu progreso".
String subscriptionSummary(AppLocalizations l10n, AccessStatus? status) {
  if (status == null || !status.hasAccess) return l10n.progressPlanInactive;
  final trialEnd = status.trialEndsAt ?? status.currentPeriodEnd;
  if (status.entitlementStatus == EntitlementStatus.trialing &&
      trialEnd != null) {
    return l10n.progressTrialUntil(formatLongDate(trialEnd));
  }
  final periodEnd = status.currentPeriodEnd;
  return periodEnd == null
      ? l10n.progressPlanActive
      : l10n.progressPlanActiveUntil(formatLongDate(periodEnd));
}
