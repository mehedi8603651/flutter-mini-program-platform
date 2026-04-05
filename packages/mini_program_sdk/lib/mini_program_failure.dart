import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Failure details surfaced by the SDK when a mini-program cannot continue.
@immutable
class MiniProgramFailure {
  const MiniProgramFailure({
    required this.message,
    this.errorCode,
    this.details = const <String, dynamic>{},
    this.fallback,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final String? errorCode;
  final Map<String, dynamic> details;
  final MiniProgramFallback? fallback;
  final Object? cause;
  final StackTrace? stackTrace;

  String get displayMessage {
    final fallbackMessage = fallback?.message?.trim();
    if (fallbackMessage != null && fallbackMessage.isNotEmpty) {
      return fallbackMessage;
    }
    return message;
  }
}

/// Internal exception used to move structured failure details through futures.
class MiniProgramLoadException implements Exception {
  const MiniProgramLoadException(this.failure);

  final MiniProgramFailure failure;

  @override
  String toString() =>
      'MiniProgramLoadException(errorCode: ${failure.errorCode}, message: ${failure.message})';
}
