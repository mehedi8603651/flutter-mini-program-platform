part of '../miniprogram_cli.dart';

extension _MiniprogramCliResultFormatters on MiniprogramCli {
  String _formatWorkflowStatusResult(MiniProgramWorkflowStatusResult result) {
    final json = result.json;
    final workspace = json['workspace'] as Map<String, Object?>;
    final environment = json['environment'] as Map<String, Object?>;
    final miniProgram = json['miniProgram'] as Map<String, Object?>;
    final hostApp = json['hostApp'] as Map<String, Object?>;
    final backend = json['backend'] as Map<String, Object?>;
    final remote = json['remote'] as Map<String, Object?>;
    final nextActions = (json['nextActions'] as List).cast<String>();
    final lines = <String>[
      'MiniProgram workflow status',
      'Workspace: ${workspace['path']}',
      'Type: ${workspace['type']}',
      'Ready: ${json['ready']}',
      'Severity: ${json['severity']}',
    ];
    if (miniProgram['detected'] == true) {
      final build = miniProgram['build'] as Map<String, Object?>;
      final validation = miniProgram['validation'] as Map<String, Object?>;
      lines.addAll(<String>[
        'Mini-program: ${miniProgram['appId'] ?? 'unknown'}',
        'Version: ${miniProgram['version'] ?? 'unknown'}',
        'Screen format: ${miniProgram['screenFormat'] ?? 'mp'}',
        'Build: ${build['exists'] == true ? 'found' : 'missing'} (${build['screenCount']} screen JSON file(s))',
        'Validation: ${validation['status']}',
        'Partner packages: ${(miniProgram['partnerPackages'] as List).length}',
      ]);
    }
    if (hostApp['detected'] == true) {
      lines.addAll(<String>[
        'Host runtime setup: ${hostApp['runtimeSetupExists']}',
        'Host endpoint map: ${hostApp['endpointMapExists']}',
        'Endpoint count: ${hostApp['endpointCount']}',
      ]);
    }
    lines.addAll(<String>[
      'Environment configured: ${environment['configured']}',
      if (environment['selectedEnvironment'] != null)
        'Environment: ${environment['selectedEnvironment']}',
      if (environment['provider'] != null)
        'Provider: ${environment['provider']}',
      if (environment['apiBaseUrl'] != null)
        'API base URL: ${environment['apiBaseUrl']}',
      'Artifact host configured: ${backend['configured']}',
      'Remote checked: ${remote['checked']}',
    ]);
    if ((remote['errors'] as List?)?.isNotEmpty == true) {
      lines.add('Remote errors: ${(remote['errors'] as List).join('; ')}');
    }
    if (nextActions.isEmpty) {
      lines.add('Next step: no immediate action.');
    } else {
      lines.add('Next actions:');
      lines.addAll(nextActions.map((action) => '- $action'));
    }
    return lines.join('\n');
  }

  String _formatCreateResult(MiniProgramScaffoldResult result) {
    final lines = <String>[
      'Created mini-program scaffold: ${result.miniProgramId}',
      'Root: ${result.miniProgramRootPath}',
      if (result.repoRootPath != null) 'Repo root: ${result.repoRootPath}',
      'Screen format: ${result.screenFormat}',
      'Capabilities: ${result.capabilities.join(', ')}',
      'Files:',
      ...result.createdPaths.map((path) => '- $path'),
    ];
    return lines.join('\n');
  }

  String _formatDoctorResult(MiniprogramDoctorResult result) {
    final lines = <String>['Miniprogram doctor report:'];
    var okCount = 0;
    var warningCount = 0;
    var errorCount = 0;
    var skippedCount = 0;

    for (final check in result.checks) {
      switch (check.status) {
        case MiniprogramDoctorCheckStatus.ok:
          okCount++;
        case MiniprogramDoctorCheckStatus.warning:
          warningCount++;
        case MiniprogramDoctorCheckStatus.error:
          errorCount++;
        case MiniprogramDoctorCheckStatus.skipped:
          skippedCount++;
      }
      lines.add('[${check.status.name}] ${check.label}: ${check.summary}');
      if (check.detail case final detail? when detail.trim().isNotEmpty) {
        lines.add('  $detail');
      }
    }

    lines.add(
      'Summary: $okCount ok, $warningCount warning, '
      '$errorCount error, $skippedCount skipped',
    );
    return lines.join('\n');
  }

  String _formatCapabilities(Map<String, Object?> capabilities) {
    final lines = <String>[
      'MiniProgram tooling capabilities.',
      'Version: ${capabilities['toolingVersion']}',
      'Package: ${capabilities['packageName']}',
      'Capabilities:',
    ];
    for (final capabilityId in _capabilityIds) {
      lines.add('- $capabilityId');
    }
    return lines.join('\n');
  }

  String _formatBuildResult(MiniProgramBuildResult result) {
    final lines = <String>[
      'Built mini-program: ${result.miniProgramId}',
      'Root: ${result.miniProgramRootPath}',
      if (result.repoRootPath != null) 'Repo root: ${result.repoRootPath}',
      'CLI source: ${result.cliSource}',
      'Command: ${result.invocation.join(' ')}',
      'Output directory: ${result.outputDirectoryPath}',
      'Entry screen JSON: ${result.entryScreenJsonPath}',
      'Ran pub get: ${result.pubGetRan}',
    ];
    return lines.join('\n');
  }

  String _formatPublishResult(MiniProgramPublishResult result) {
    final lines = <String>[
      'Published mini-program: ${result.miniProgramId}',
      'Version: ${result.version}',
      'Artifact workspace root: ${result.backendRootPath}',
      'Screen format: ${result.buildResult.screenFormat}',
      if (result.buildResult.screenSchemaVersion != null)
        'Screen schema version: ${result.buildResult.screenSchemaVersion}',
      'Build CLI source: ${result.buildResult.cliSource}',
      'Built entry screen: ${result.buildResult.entryScreenJsonPath}',
      'Pre-publish validation: ${result.prePublishValidation.errorCount} error(s), ${result.prePublishValidation.warningCount} warning(s)',
      'Post-publish validation: ${result.postPublishValidation.errorCount} error(s), ${result.postPublishValidation.warningCount} warning(s)',
      'Latest manifest: ${result.latestManifestPath}',
      'Versioned manifest: ${result.versionedManifestPath}',
      'Published screens: ${result.screensDirectoryPath} (${result.copiedScreenCount} file(s))',
    ];
    return lines.join('\n');
  }

  String _formatStaticPublishResult(MiniProgramStaticPublishResult result) {
    final lines = <String>[
      'Published mini-program to static folder: ${result.miniProgramId}',
      'Version: ${result.version}',
      'Output folder: ${result.outputPath}',
      'Screen format: ${result.buildResult.screenFormat}',
      if (result.buildResult.screenSchemaVersion != null)
        'Screen schema version: ${result.buildResult.screenSchemaVersion}',
      'Build CLI source: ${result.buildResult.cliSource}',
      'Built entry screen: ${result.buildResult.entryScreenJsonPath}',
      'Latest manifest: ${result.manifestLatestPath}',
      'Versioned manifest: ${result.manifestVersionPath}',
      'Screens directory: ${result.screensDirectoryPath}',
      if (result.assetsDirectoryPath != null)
        'Assets directory: ${result.assetsDirectoryPath}',
      'Release metadata: ${result.metadataReleasePath}',
      'Catalog metadata: ${result.metadataCatalogPath}',
      'Instructions: ${result.instructionsPath}',
      'GitHub Pages marker: ${result.nojekyllPath}',
      'Cleaned generated output first: ${result.cleaned}',
      'Written files: ${result.writtenFiles.length}',
      'Published at UTC: ${result.publishedAtUtc}',
      'Host endpoint example:',
      'MiniProgramEndpoint.public(apiBaseUri: Uri.parse(\'https://your-cdn.example.com/public_mini_program/\'))',
    ];
    return lines.join('\n');
  }

  String _formatPartnerPackageResult(MiniProgramPartnerPackageResult result) {
    return <String>[
      'Created MiniProgram partner handoff package.',
      'Package file: ${result.filePath}',
      'Mini-program: ${result.handoff.appId}',
      'Title: ${result.handoff.title}',
      'Artifact base URL: ${result.handoff.artifactBaseUri}',
      'Generated at UTC: ${result.handoff.generatedAtUtc}',
      'Host import command:',
      'miniprogram host endpoint import ${result.filePath}',
    ].join('\n');
  }

  String _formatHostEndpointAddResult(MiniProgramHostEndpointAddResult result) {
    return <String>[
      result.created
          ? 'Created MiniProgram host endpoint map.'
          : result.updated
          ? 'Updated MiniProgram host endpoint.'
          : 'Added MiniProgram host endpoint.',
      'Project root: ${result.projectRootPath}',
      'Endpoint file: ${result.filePath}',
      'Registry file: ${result.registryFilePath}',
      'Mini-program: ${result.appId}',
      'Title: ${result.title}',
      'Artifact base URL: ${result.apiBaseUri}',
      'Runtime API mode: ${result.backendMode}',
      if (result.backendBaseUri != null)
        'Middle-server API URL: ${result.backendBaseUri}',
      'Endpoint count: ${result.endpointCount}',
      'Registry count: ${result.registryCount}',
      'Use it from MiniProgramScope:',
      'config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),',
    ].join('\n');
  }

  String _formatHostEndpointImportResult({
    required String packagePath,
    required MiniProgramPartnerHandoff handoff,
    required MiniProgramHostEndpointAddResult endpointResult,
  }) {
    return <String>[
      endpointResult.created
          ? 'Imported MiniProgram partner handoff and created endpoint map.'
          : endpointResult.updated
          ? 'Imported MiniProgram partner handoff and updated endpoint.'
          : 'Imported MiniProgram partner handoff and added endpoint.',
      'Package file: $packagePath',
      'Project root: ${endpointResult.projectRootPath}',
      'Endpoint file: ${endpointResult.filePath}',
      'Registry file: ${endpointResult.registryFilePath}',
      'Mini-program: ${handoff.appId}',
      'Title: ${handoff.title}',
      'Artifact base URL: ${handoff.artifactBaseUri}',
      'Endpoint count: ${endpointResult.endpointCount}',
      'Registry count: ${endpointResult.registryCount}',
      'Open from app UI by appId only:',
      "openAppMiniProgram(context, appId: '${handoff.appId}', title: ...);",
    ].join('\n');
  }

  String _formatEmbeddingInitResult(MiniProgramEmbeddingInitResult result) {
    final lines = <String>[
      'Initialized embedded mini-program adapter for: ${result.packageName}',
      'Project root: ${result.projectRootPath}',
      if (result.repoRootPath != null) 'Repo root: ${result.repoRootPath}',
      'Host app id: ${result.hostAppId}',
      'Host version: ${result.hostVersion}',
      'Files:',
      ...result.createdPaths.map((path) => '- $path'),
    ];
    return lines.join('\n');
  }

  String _formatHostRunStart({
    required String projectRootPath,
    required String deviceId,
    required String? environmentName,
    required String backendApiBaseUrl,
  }) {
    return <String>[
      'Running embedded host app.',
      'Project root: $projectRootPath',
      'Device: $deviceId',
      if (environmentName != null) 'Environment: $environmentName',
      if (backendApiBaseUrl.trim().isEmpty)
        'Artifact API base URL: generated runtime default'
      else
        'Artifact API base URL: $backendApiBaseUrl',
    ].join('\n');
  }

  String _formatEnvStatusResult(
    ResolvedLocalCliEnvironmentState? resolved, {
    bool initialized = false,
    bool switched = false,
  }) {
    if (resolved == null) {
      return 'No miniprogram env configuration was found. Run '
          '"miniprogram env init" from your mini-program workspace or repo '
          'root first.';
    }

    final lines = <String>[
      if (initialized)
        'Initialized miniprogram env.'
      else if (switched)
        'Updated active miniprogram environment.'
      else
        'Miniprogram env configuration found.',
      'Config scope: ${resolved.scope}',
      'Config root: ${resolved.rootPath}',
      'Config file: ${resolved.filePath}',
      'Repo root: ${resolved.state.repoRootPath ?? 'not configured'}',
      'Active environment: ${resolved.state.activeEnvironment}',
      'Initialized at UTC: ${resolved.state.initializedAtUtc}',
      'Updated at UTC: ${resolved.state.updatedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatEnvListResult(ResolvedLocalCliEnvironmentState resolved) {
    final lines = <String>[
      'Configured environments:',
      '${resolved.state.activeEnvironment == 'local' ? '*' : '-'} local',
    ];
    return lines.join('\n');
  }

  String _formatBackendStartResult(LocalBackendStartResult result) {
    final state = result.state;
    final lines = <String>[
      result.alreadyRunning
          ? 'Local artifact host was already running.'
          : 'Started local artifact host.',
      'PID: ${state.pid}',
      'Port: ${state.port}',
      'Health URL: ${state.healthCheckUrl}',
      ..._formatBackendTargetUrls(state.port),
      'stdout log: ${state.stdoutLogPath}',
      'stderr log: ${state.stderrLogPath}',
    ];
    if (result.reversedDeviceIds.isNotEmpty) {
      lines.add(
        'ADB reverse: ${result.reversedDeviceIds.join(', ')} '
        '(tcp:${state.port} -> tcp:${state.port})',
      );
    }
    return lines.join('\n');
  }

  String _formatBackendInitResult(LocalBackendInitResult result) {
    final lines = <String>[
      'Initialized local artifact host workspace.',
      'Artifact workspace root: ${result.backendRootPath}',
      'API root: ${result.apiRootPath}',
      'Service root: ${result.serviceDirectoryPath}',
      'State file: ${result.stateFilePath}',
      'Global fallback: ${result.globalStateFilePath}',
      'Files:',
      ...result.createdPaths.map((path) => '- $path'),
    ];
    return lines.join('\n');
  }

  String _formatBackendStatusResult(LocalBackendStatusResult result) {
    if (!result.hasState) {
      return 'Local artifact host is not running. No backend.local.json state was found.';
    }

    final state = result.state!;
    final lines = <String>[
      'Local artifact host state found.',
      'PID: ${state.pid}',
      'Port: ${state.port}',
      'Process alive: ${result.processAlive}',
      'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status code: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      ..._formatBackendTargetUrls(state.port),
      'stdout log: ${state.stdoutLogPath}',
      'stderr log: ${state.stderrLogPath}',
    ];
    return lines.join('\n');
  }

  List<String> _formatBackendTargetUrls(int port) {
    return <String>[
      'Android emulator URL: http://10.0.2.2:$port/api/',
      'Desktop/Chrome URL: http://127.0.0.1:$port/api/',
      'Android USB via adb reverse: http://127.0.0.1:$port/api/',
    ];
  }

  String _formatBackendStopResult(LocalBackendStopResult result) {
    if (!result.hadState) {
      return 'No local artifact host state was found.';
    }
    if (result.clearedStaleState) {
      return 'Cleared stale local artifact host state. The recorded process was already gone.';
    }
    if (result.stopped) {
      return 'Stopped the local artifact host and cleared backend.local.json.';
    }
    return 'Local artifact host was not running.';
  }

  String _formatBackendResetResult(LocalBackendResetResult result) {
    final lines = <String>[
      'Removed ${result.removedPaths.length} tracked local artifact path(s).',
    ];
    if (result.removedPaths.isNotEmpty) {
      lines.addAll(result.removedPaths.map((path) => '- $path'));
    }
    return lines.join('\n');
  }
}
