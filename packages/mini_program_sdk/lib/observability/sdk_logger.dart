import 'package:flutter/foundation.dart';

/// Minimal logger contract used by the SDK for diagnostics and failures.
abstract interface class SdkLogger {
  void info(String message, {Map<String, Object?> context = const {}});

  void warn(String message, {Map<String, Object?> context = const {}});

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  });
}

/// Default logger that writes SDK diagnostics through `debugPrint`.
class DebugPrintSdkLogger implements SdkLogger {
  const DebugPrintSdkLogger();

  @override
  void info(String message, {Map<String, Object?> context = const {}}) {
    debugPrint(_format('INFO', message, context: context));
  }

  @override
  void warn(String message, {Map<String, Object?> context = const {}}) {
    debugPrint(_format('WARN', message, context: context));
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    debugPrint(
      _format(
        'ERROR',
        message,
        context: context,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  String _format(
    String level,
    String message, {
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer('[mini_program_sdk][$level] $message');

    if (context.isNotEmpty) {
      buffer.write(' | context=$context');
    }

    if (error != null) {
      buffer.write(' | error=$error');
    }

    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }

    return buffer.toString();
  }
}
