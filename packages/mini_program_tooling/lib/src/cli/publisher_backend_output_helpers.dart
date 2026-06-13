part of '../miniprogram_cli.dart';

extension _MiniprogramCliPublisherBackendOutputHelpers on MiniprogramCli {
  String _formatPublisherBackendScaffoldResult(
    PublisherBackendScaffoldResult result,
  ) {
    final lines = <String>[
      'Scaffolded local Publisher API mock.',
      'Template: ${result.template}',
      if (result.storageMode != null) 'Storage: ${result.storageMode}',
      'Mini-program root: ${result.miniProgramRootPath}',
      'Mock API root: ${result.backendRootPath}',
      'Created files: ${result.createdPaths.length}',
    ];
    lines.addAll(result.createdPaths.map((filePath) => '- $filePath'));
    lines.addAll(<String>[
      '',
      'Run locally:',
      'miniprogram publisher-api run --mini-program-root "${result.miniProgramRootPath}" --port 9090',
      '',
      'External API flow:',
      'miniprogram publisher-api contract init --mini-program-root "${result.miniProgramRootPath}" --backend-base-url <https-api-url>',
      'miniprogram publisher-api contract smoke --mini-program-root "${result.miniProgramRootPath}"',
      'miniprogram publisher-api contract handoff --mini-program-root "${result.miniProgramRootPath}" --delivery-url <delivery-url> --public',
    ]);
    return lines.join('\n');
  }

  String _formatPublisherBackendRunResult(PublisherBackendRunResult result) {
    final state = result.state;
    return <String>[
      result.alreadyRunning
          ? 'Publisher API mock was already running.'
          : 'Started Publisher API mock.',
      'Mini-program root: ${state.miniProgramRootPath}',
      'Mock API root: ${state.backendRootPath}',
      'PID: ${state.pid}',
      'Health: ${state.healthCheckUrl}',
      ..._formatPublisherBackendTargetUrls(state.port),
      'stdout log: ${state.stdoutLogPath}',
      'stderr log: ${state.stderrLogPath}',
    ].join('\n');
  }

  String _formatPublisherBackendStatusResult(
    PublisherBackendStatusResult result,
  ) {
    if (!result.hasState) {
      return 'Publisher API mock is not running. No publisher_backend.local.json state was found.';
    }
    final state = result.state!;
    return <String>[
      'Publisher API mock state found.',
      'Mini-program root: ${state.miniProgramRootPath}',
      'Mock API root: ${state.backendRootPath}',
      'PID: ${state.pid}',
      'Process alive: ${result.processAlive}',
      'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      ..._formatPublisherBackendTargetUrls(state.port),
    ].join('\n');
  }

  String _formatPublisherBackendStopResult(PublisherBackendStopResult result) {
    if (!result.hadState) {
      return 'No Publisher API mock state was found.';
    }
    if (result.clearedStaleState) {
      return 'Cleared stale Publisher API mock state. The recorded process was already gone.';
    }
    if (result.stopped) {
      return 'Stopped the Publisher API mock and cleared publisher_backend.local.json.';
    }
    return 'Publisher API mock was not running.';
  }

  String _formatPublisherBackendUrlsResult(PublisherBackendUrlsResult result) {
    return <String>[
      'Publisher API mock local URLs:',
      ..._formatPublisherBackendTargetUrls(result.port),
      '',
      'Host endpoint examples:',
      'miniprogram host endpoint add <appId> --artifact-base-url <artifact-base-url> --backend-local-mock',
      'miniprogram host endpoint add <appId> --artifact-base-url <artifact-base-url> --backend-base-url ${result.desktopBaseUrl}',
      '',
      'Use --backend-local-mock for generated host config. With mini_program_sdk 0.3.5+,',
      'the SDK falls back between 127.0.0.1/localhost and Android emulator 10.0.2.2.',
      'Real Android/iOS devices need a LAN IP URL or adb reverse.',
    ].join('\n');
  }

  List<String> _formatPublisherBackendTargetUrls(int port) {
    return <String>[
      'Desktop/iOS/physical device base URL: http://127.0.0.1:$port',
      'Android emulator base URL: http://10.0.2.2:$port',
      'Health URL: http://127.0.0.1:$port/health',
      'Sample home URL: http://127.0.0.1:$port/home/bootstrap',
      'Sample paged URL: http://127.0.0.1:$port/coupons/page?limit=2',
    ];
  }
}
