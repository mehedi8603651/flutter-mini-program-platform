import 'dart:async';
import 'dart:io';

import 'dependencies.dart';

class LocalBackendHealthResult {
  const LocalBackendHealthResult({
    required this.healthy,
    this.statusCode,
    this.error,
  });

  final bool healthy;
  final int? statusCode;
  final String? error;
}

class LocalBackendHealthMonitor {
  const LocalBackendHealthMonitor(this.dependencies);

  final LocalBackendDependencies dependencies;

  Future<LocalBackendHealthResult> probe(
    Uri uri, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final response = await dependencies.healthGetter(uri).timeout(timeout);
      return LocalBackendHealthResult(
        healthy: response.statusCode == 200,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : 'Health endpoint returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return const LocalBackendHealthResult(
        healthy: false,
        error: 'Health check timed out.',
      );
    } catch (error) {
      return LocalBackendHealthResult(healthy: false, error: '$error');
    }
  }

  Future<LocalBackendHealthResult> waitUntilHealthy(
    Uri uri, {
    required Duration timeout,
  }) async {
    final deadline = dependencies.clock().add(timeout);
    LocalBackendHealthResult lastResult = const LocalBackendHealthResult(
      healthy: false,
      error: 'Health check did not start responding yet.',
    );

    while (dependencies.clock().isBefore(deadline)) {
      lastResult = await probe(uri, timeout: const Duration(seconds: 1));
      if (lastResult.healthy) {
        return lastResult;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    return lastResult;
  }

  Future<bool> waitUntilUnavailable(
    Uri uri, {
    required Duration timeout,
  }) async {
    final deadline = dependencies.clock().add(timeout);
    while (dependencies.clock().isBefore(deadline)) {
      final result = await probe(
        uri,
        timeout: const Duration(milliseconds: 750),
      );
      if (!result.healthy) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final finalProbe = await probe(
      uri,
      timeout: const Duration(milliseconds: 750),
    );
    return !finalProbe.healthy;
  }

  Future<String> readLogTail(String filePath, {int lineCount = 20}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '';
    }

    final lines = await file.readAsLines();
    if (lines.isEmpty) {
      return '';
    }
    final startIndex = lines.length > lineCount ? lines.length - lineCount : 0;
    return lines.sublist(startIndex).join('\n').trim();
  }
}
