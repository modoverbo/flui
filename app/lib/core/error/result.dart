import 'package:flui/core/error/failure.dart';
import 'package:meta/meta.dart';

/// The outcome of an operation that can fail in an expected way.
///
/// Repositories return `Result` instead of throwing, so callers handle
/// failures with an exhaustive `switch`.
@immutable
sealed class Result<T> {
  const new();

  const factory ok(T value) = Ok<T>;

  const factory err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Result.ok(transform(value)),
    Err(:final failure) => Result.err(failure),
  };
}

@immutable
final class Ok<T> extends Result<T> {
  const new(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

@immutable
final class Err<T> extends Result<T> {
  const new(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}
