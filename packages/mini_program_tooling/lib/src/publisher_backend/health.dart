import 'dart:async';
import 'dart:io';

import 'dependencies.dart';

class PublisherBackendHealthResult {
  const PublisherBackendHealthResult({
    required this.healthy,
    this.statusCode,
    this.error,
  });

  final bool healthy;
  final int? statusCode;
  final String? error;
}

class PublisherBackendHealthMonitor {
  const PublisherBackendHealthMonitor(this.dependencies);

  final PublisherBackendDependencies dependencies;

  Future<PublisherBackendHealthResult> probe(
    Uri uri, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final response = await dependencies.healthGetter(uri).timeout(timeout);
      return PublisherBackendHealthResult(
        healthy: response.statusCode == 200,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : 'Health endpoint returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return const PublisherBackendHealthResult(
        healthy: false,
        error: 'Health check timed out.',
      );
    } catch (error) {
      return PublisherBackendHealthResult(healthy: false, error: '$error');
    }
  }

  Future<PublisherBackendHealthResult> waitUntilHealthy(
    Uri uri, {
    required Duration timeout,
    Duration attemptTimeout = const Duration(seconds: 1),
    Duration retryDelay = const Duration(milliseconds: 250),
  }) async {
    final deadline = dependencies.clock().add(timeout);
    PublisherBackendHealthResult lastResult =
        const PublisherBackendHealthResult(
          healthy: false,
          error: 'Health check did not start responding yet.',
        );
    while (dependencies.clock().isBefore(deadline)) {
      lastResult = await probe(uri, timeout: attemptTimeout);
      if (lastResult.healthy) {
        return lastResult;
      }
      await dependencies.delay(retryDelay);
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
      await dependencies.delay(const Duration(milliseconds: 250));
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
    return lines
        .skip(lines.length > lineCount ? lines.length - lineCount : 0)
        .join('\n');
  }
}
