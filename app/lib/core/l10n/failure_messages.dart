import 'package:flui/core/error/failure.dart';
import 'package:flui/core/l10n/gen/app_localizations.dart';

/// User-facing copy for a failure. Kind, short, never blaming.
String failureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    NetworkFailure() => l10n.errorNetwork,
    ConfigFailure() || UnexpectedFailure() => l10n.errorUnexpected,
    // Diagnosis surfaces (U14a/U14c) show the retake-available date instead
    // of this generic copy; this branch only keeps the switch exhaustive.
    SkillProfileFailure() => l10n.errorUnexpected,
    AuthFailure(:final code) => switch (code) {
      AuthErrorCode.invalidCredentials => l10n.authErrorInvalidCredentials,
      AuthErrorCode.emailAlreadyInUse => l10n.authErrorEmailInUse,
      AuthErrorCode.weakPassword => l10n.authErrorWeakPassword,
      AuthErrorCode.emailNotConfirmed => l10n.authErrorEmailNotConfirmed,
      AuthErrorCode.rateLimited => l10n.authErrorRateLimited,
      AuthErrorCode.signUpDisabled => l10n.authErrorSignUpDisabled,
      AuthErrorCode.unknown => l10n.errorUnexpected,
    },
    SubscriptionFailure(:final code) => switch (code) {
      SubscriptionErrorCode.alreadySubscribed => l10n.paywallAlreadySubscribed,
      SubscriptionErrorCode.unknownPlan ||
      SubscriptionErrorCode.checkoutUnavailable =>
        l10n.paywallCheckoutUnavailable,
      SubscriptionErrorCode.couldNotOpenCheckout ||
      SubscriptionErrorCode.unauthorized ||
      SubscriptionErrorCode.unknown => l10n.paywallCheckoutError,
    },
    SpeechAnalysisFailure(:final code) => switch (code) {
      SpeechAnalysisErrorCode.accessRequired =>
        l10n.speechAnalysisAccessRequired,
      SpeechAnalysisErrorCode.accessUnavailable =>
        l10n.speechAnalysisAccessUnavailable,
      SpeechAnalysisErrorCode.dailyLimitReached =>
        l10n.speechAnalysisDailyLimitReached,
      SpeechAnalysisErrorCode.rateLimited => l10n.speechAnalysisRateLimited,
      SpeechAnalysisErrorCode.noSpeech => l10n.speechAnalysisNoSpeech,
      SpeechAnalysisErrorCode.unknown => l10n.errorUnexpected,
    },
    // "Eliminar mi cuenta" (U22e): a distinct, honest message per bucket —
    // never the generic unexpected-error copy, so the user knows whether to
    // retry now, retry later, or contact support.
    AccountDeletionFailure(:final code) => switch (code) {
      AccountDeletionErrorCode.billingUnavailable =>
        l10n.accountDeletionErrorBillingUnavailable,
      AccountDeletionErrorCode.membershipNotFound =>
        l10n.accountDeletionErrorContactSupport,
      AccountDeletionErrorCode.deletionFailed =>
        l10n.accountDeletionErrorTryAgain,
      AccountDeletionErrorCode.unknown => l10n.errorUnexpected,
    },
  };
}
