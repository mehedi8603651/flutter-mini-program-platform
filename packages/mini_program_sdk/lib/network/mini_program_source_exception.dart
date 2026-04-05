/// Structured source-layer failure used by backend and asset loaders.
class MiniProgramSourceException implements Exception {
  const MiniProgramSourceException({
    required this.message,
    this.errorCode,
    this.statusCode,
    this.details = const <String, dynamic>{},
  });

  final String message;
  final String? errorCode;
  final int? statusCode;
  final Map<String, dynamic> details;

  @override
  String toString() =>
      'MiniProgramSourceException(statusCode: $statusCode, errorCode: $errorCode, message: $message)';
}
