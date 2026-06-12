part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterRuntimeHelpers on PublisherBackendStarter {
  Future<bool> _isProcessAlive(int pid) async {
    if (Platform.isWindows) {
      final result = await _shellRunner('tasklist', <String>[
        '/FI',
        'PID eq $pid',
        '/FO',
        'CSV',
        '/NH',
      ]);
      if (result.exitCode != 0) {
        return false;
      }
      final output = '${result.stdout}'.trim();
      return output.isNotEmpty &&
          !output.toLowerCase().contains('no tasks are running');
    }
    final result = await _shellRunner('ps', <String>['-p', '$pid']);
    if (result.exitCode != 0) {
      return false;
    }
    return const LineSplitter().convert('${result.stdout}'.trim()).length > 1;
  }

  Future<ProcessResult> _terminateProcess(int pid) {
    if (Platform.isWindows) {
      return _shellRunner('taskkill', <String>['/PID', '$pid', '/T', '/F']);
    }
    return _shellRunner('kill', <String>['$pid']);
  }

  Future<_PublisherBackendHealth> _probeHealth(
    Uri uri, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final response = await _healthGetter(uri).timeout(timeout);
      return _PublisherBackendHealth(
        healthy: response.statusCode == 200,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : 'Health endpoint returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return const _PublisherBackendHealth(
        healthy: false,
        error: 'Health check timed out.',
      );
    } catch (error) {
      return _PublisherBackendHealth(healthy: false, error: '$error');
    }
  }

  Future<_PublisherBackendHealth> _waitForHealthCheck(
    Uri uri, {
    required Duration timeout,
    Duration attemptTimeout = const Duration(seconds: 1),
    Duration retryDelay = const Duration(milliseconds: 250),
  }) async {
    final deadline = _clock().add(timeout);
    _PublisherBackendHealth lastResult = const _PublisherBackendHealth(
      healthy: false,
      error: 'Health check did not start responding yet.',
    );
    while (_clock().isBefore(deadline)) {
      lastResult = await _probeHealth(uri, timeout: attemptTimeout);
      if (lastResult.healthy) {
        return lastResult;
      }
      await _delay(retryDelay);
    }
    return lastResult;
  }

  Future<bool> _waitForBackendUnavailable(
    Uri uri, {
    required Duration timeout,
  }) async {
    final deadline = _clock().add(timeout);
    while (_clock().isBefore(deadline)) {
      final result = await _probeHealth(
        uri,
        timeout: const Duration(milliseconds: 750),
      );
      if (!result.healthy) {
        return true;
      }
      await _delay(const Duration(milliseconds: 250));
    }
    final finalProbe = await _probeHealth(
      uri,
      timeout: const Duration(milliseconds: 750),
    );
    return !finalProbe.healthy;
  }

  Future<String> _readLogTail(String filePath, {int lineCount = 20}) async {
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
