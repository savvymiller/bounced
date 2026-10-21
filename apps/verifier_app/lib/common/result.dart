/// A generic success/failure wrapper for async operations (API calls, local
/// storage reads, etc.) — unrelated to `VerificationOutcome`, which already
/// encodes its own six-case outcome taxonomy and has no need for this
/// wrapper around it.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;

  const factory Result.failure(Object error, [StackTrace? stackTrace]) =
      Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Pattern-matches this result, ensuring both cases are always handled.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Object error, StackTrace? stackTrace) onFailure,
  }) {
    return switch (this) {
      Success(value: final value) => onSuccess(value),
      Failure(error: final error, stackTrace: final stackTrace) => onFailure(
        error,
        stackTrace,
      ),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}
