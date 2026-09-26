import 'package:meta/meta.dart';

/// Typed failures returned inside `Result.err`.
///
/// Presentation maps each failure to user-facing copy; domain and data never
/// build UI strings. Add new subtypes here when a feature needs a new kind.
@immutable
sealed class Failure implements Exception {
  const new();
}

/// The device could not reach the backend.
@immutable
final class NetworkFailure extends Failure {
  const new();

  @override
  bool operator ==(Object other) => other is NetworkFailure;

  @override
  int get hashCode => (NetworkFailure).hashCode;

  @override
  String toString() => 'NetworkFailure()';
}

/// Invalid or missing compile-time configuration (developer error).
@immutable
final class ConfigFailure extends Failure {
  const new(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is ConfigFailure && other.message == message;

  @override
  int get hashCode => Object.hash(ConfigFailure, message);

  @override
  String toString() => 'ConfigFailure($message)';
}

/// Anything the app does not know how to handle. [cause] is kept for logs.
@immutable
final class UnexpectedFailure extends Failure {
  const new([this.cause]);

  final Object? cause;

  @override
  bool operator ==(Object other) =>
      other is UnexpectedFailure && other.cause == cause;

  @override
  int get hashCode => Object.hash(UnexpectedFailure, cause);

  @override
  String toString() => 'UnexpectedFailure($cause)';
}

enum AuthErrorCode {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  emailNotConfirmed,
  rateLimited,
  signUpDisabled,
  unknown,
}

@immutable
final class AuthFailure extends Failure {
  const new(this.code);

  final AuthErrorCode code;

  @override
  bool operator ==(Object other) => other is AuthFailure && other.code == code;

  @override
  int get hashCode => Object.hash(AuthFailure, code);

  @override
  String toString() => 'AuthFailure($code)';
}

enum SubscriptionErrorCode {
  alreadySubscribed,
  unknownPlan,
  unauthorized,
  checkoutUnavailable,
  couldNotOpenCheckout,
  unknown,
}

@immutable
final class SubscriptionFailure extends Failure {
  const new(this.code);

  final SubscriptionErrorCode code;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionFailure && other.code == code;

  @override
  int get hashCode => Object.hash(SubscriptionFailure, code);

  @override
  String toString() => 'SubscriptionFailure($code)';
}

enum SpeechAnalysisErrorCode {
  accessRequired,
  accessUnavailable,
  dailyLimitReached,
  rateLimited,
  unknown,
}

@immutable
final class SpeechAnalysisFailure extends Failure {
  const new(this.code);

  final SpeechAnalysisErrorCode code;

  @override
  bool operator ==(Object other) =>
      other is SpeechAnalysisFailure && other.code == code;

  @override
  int get hashCode => Object.hash(SpeechAnalysisFailure, code);

  @override
  String toString() => 'SpeechAnalysisFailure($code)';
}
