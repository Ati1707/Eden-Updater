/// A result type that can represent either success or failure
sealed class Result<T> {
  const Result();
}

/// Represents a successful result
class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

/// Represents a failed result
class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;

  const Failure(this.message, [this.exception]);
}

/// Extension methods for Result
extension ResultExtensions<T> on Result<T> {
  /// Check if the result is successful
  bool get isSuccess => this is Success<T>;

  /// Check if the result is a failure
  bool get isFailure => this is Failure<T>;

  /// Get the data if successful, null otherwise
  T? get dataOrNull => switch (this) {
    Success<T>(data: final data) => data,
    Failure<T>() => null,
  };

  /// Get the error message if failed, null otherwise
  String? get errorOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(message: final message) => message,
  };

  /// Transform the data if successful
  Result<R> map<R>(R Function(T) transform) => switch (this) {
    Success<T>(data: final data) => Success(transform(data)),
    Failure<T>(message: final message, exception: final exception) => Failure(
      message,
      exception,
    ),
  };

  /// Handle both success and failure cases
  R fold<R>(
    R Function(T) onSuccess,
    R Function(String, Exception?) onFailure,
  ) => switch (this) {
    Success<T>(data: final data) => onSuccess(data),
    Failure<T>(message: final message, exception: final exception) => onFailure(
      message,
      exception,
    ),
  };
}
