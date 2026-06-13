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
      'Backend configured: ${backend['configured']}',
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
      'Backend root: ${result.backendRootPath}',
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

  String _formatCloudPublishResult(MiniProgramCloudPublishResult result) {
    final versionedObjectCount = result.uploadedObjects
        .where((record) => record.versionId != null)
        .length;
    final lines = <String>[
      'Published mini-program to cloud: ${result.miniProgramId}',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Version: ${result.version}',
      'Screen format: ${result.buildResult.screenFormat}',
      if (result.buildResult.screenSchemaVersion != null)
        'Screen schema version: ${result.buildResult.screenSchemaVersion}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Build CLI source: ${result.buildResult.cliSource}',
      'Built entry screen: ${result.buildResult.entryScreenJsonPath}',
      'Artifact root key: ${result.artifactRootKey}',
      'Manifest key: ${result.manifestKey}',
      'Screens prefix: ${result.screensPrefixKey}',
      if (result.assetsPrefixKey != null)
        'Assets prefix: ${result.assetsPrefixKey}',
      'Release metadata key: ${result.metadataReleaseKey}',
      'Catalog metadata key: ${result.metadataCatalogKey}',
      if (result.cloudFrontBaseUrl != null)
        'CloudFront base URL: ${result.cloudFrontBaseUrl}',
      if (result.apiBaseUrl != null) 'API base URL: ${result.apiBaseUrl}',
      'Uploaded objects: ${result.uploadedObjects.length}',
      'Versioned objects: $versionedObjectCount',
      'Published at UTC: ${result.publishedAtUtc}',
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

  String _formatFirebaseHostingPublishResult(
    MiniProgramFirebaseHostingPublishResult result,
  ) {
    final lines = <String>[
      result.dryRun
          ? 'Prepared Firebase Hosting static delivery.'
          : 'Published mini-program to Firebase Hosting.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Site: ${result.siteId}',
      'Mini-program ID: ${result.staticResult.miniProgramId}',
      'Version: ${result.staticResult.version}',
      'Screen format: ${result.staticResult.buildResult.screenFormat}',
      if (result.staticResult.buildResult.screenSchemaVersion != null)
        'Screen schema version: ${result.staticResult.buildResult.screenSchemaVersion}',
      'Hosting root: ${result.hostingRootPath}',
      'Public folder: ${result.outputPath}',
      'Firebase config: ${result.firebaseJsonPath}',
      'Delivery API base URL: ${result.deliveryApiBaseUrl}',
      'Cleaned generated output first: ${result.staticResult.cleaned}',
      'Written files: ${result.staticResult.writtenFiles.length}',
      'Deployed: ${result.deployed}',
      'Dry run: ${result.dryRun}',
      if (result.deployExitCode != null)
        'Firebase CLI exit code: ${result.deployExitCode}',
      'Published at UTC: ${result.staticResult.publishedAtUtc}',
      'Next Publisher API steps:',
      'miniprogram publisher-api contract init --backend-base-url <publisher-api-url> --public',
      'miniprogram publisher-api contract smoke',
      'miniprogram publisher-api contract handoff --delivery-url ${result.deliveryApiBaseUrl} --public',
    ];
    return lines.join('\n');
  }

  String _formatCloudDeployResult(MiniProgramCloudDeployResult result) {
    final lines = <String>[
      'Deployed cloud artifact stack.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Bucket: ${result.bucketName}',
      'Backend project root: ${result.backendProjectRootPath}',
      if (result.apiBaseUrl != null)
        'Artifact API base URL: ${result.apiBaseUrl}',
      if (result.healthUrl != null) 'Health URL: ${result.healthUrl}',
      if (result.healthy != null) 'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status code: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      'Outputs:',
      ...result.outputs.entries.map(
        (entry) => '- ${entry.key}: ${entry.value}',
      ),
      'Deployed at UTC: ${result.deployedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatCloudStatusResult(MiniProgramCloudStatusResult result) {
    final lines = <String>[
      'Cloud artifact stack status:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Stack exists: ${result.stackExists}',
      if (result.stackStatus != null) 'Stack status: ${result.stackStatus}',
      if (result.stackStatusReason != null &&
          result.stackStatusReason!.trim().isNotEmpty)
        'Stack status detail: ${result.stackStatusReason}',
      if (result.apiBaseUrl != null)
        'Artifact API base URL: ${result.apiBaseUrl}',
      if (result.healthUrl != null) 'Health URL: ${result.healthUrl}',
      if (result.healthy != null) 'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status code: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      if (result.outputs.isNotEmpty) 'Outputs:',
      if (result.outputs.isNotEmpty)
        ...result.outputs.entries.map(
          (entry) => '- ${entry.key}: ${entry.value}',
        ),
    ];
    return lines.join('\n');
  }

  String _formatCloudOutputsResult(
    MiniProgramCloudOutputsResult result, {
    required String format,
  }) {
    if (format == 'dart-define') {
      final backendApiBaseUrl = _requireBackendApiBaseUrlFromOutputs(result);
      return '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=$backendApiBaseUrl';
    }

    final lines = <String>[
      'Cloud artifact stack outputs:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Region: ${result.region}',
      ...result.outputs.entries.map(
        (entry) => '- ${entry.key}: ${entry.value}',
      ),
    ];
    return lines.join('\n');
  }

  String _formatCloudLogsResult(MiniProgramCloudLogsResult result) {
    final lines = <String>[
      'Cloud artifact stack logs:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Region: ${result.region}',
      'Lambda function: ${result.lambdaFunctionName}',
      'Since: ${result.since}',
    ];
    if (result.stdoutText.isNotEmpty) {
      lines.add(result.stdoutText);
    } else {
      lines.add('(no log lines returned)');
    }
    if (result.stderrText.isNotEmpty) {
      lines.add('stderr: ${result.stderrText}');
    }
    return lines.join('\n');
  }

  String _formatCloudDestroyResult(MiniProgramCloudDestroyResult result) {
    return <String>[
      'Destroyed cloud artifact stack.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Region: ${result.region}',
      'Deleted at UTC: ${result.deletedAtUtc}',
    ].join('\n');
  }

  String _formatCloudDoctorResult(MiniProgramCloudDoctorResult result) {
    final lines = <String>['Miniprogram cloud doctor report:'];
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

  String _formatCloudRollbackResult(MiniProgramCloudRollbackResult result) {
    return <String>[
      'Rolled back cloud release.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Version: ${result.version}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Catalog key: ${result.catalogKey}',
      'Release key: ${result.releaseKey}',
      'Rolled back at UTC: ${result.rolledBackAtUtc}',
    ].join('\n');
  }

  String _formatAccessKeyCreateResult(MiniProgramAccessKeyCreateResult result) {
    return <String>[
      'Created MiniProgram access key.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Key id: ${result.keyId}',
      'Access key: ${result.accessKey}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Policy key: ${result.policyKey}',
      'Created at UTC: ${result.createdAtUtc}',
      'Host endpoint command:',
      'miniprogram host endpoint add ${result.miniProgramId} --api-base-url <BackendApiBaseUrl> --access-key ${result.accessKey}',
    ].join('\n');
  }

  String _formatAccessKeyListResult(MiniProgramAccessKeyListResult result) {
    final lines = <String>[
      'MiniProgram access keys:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Policy key: ${result.policyKey}',
      'Policy exists: ${result.policyExists}',
    ];
    if (result.keys.isEmpty) {
      lines.add('(no keys)');
    } else {
      for (final key in result.keys) {
        lines.add(
          '- ${key.id}: ${key.active ? 'active' : 'revoked'} '
          '(created ${key.createdAtUtc}, updated ${key.updatedAtUtc})',
        );
      }
    }
    return lines.join('\n');
  }

  String _formatAccessKeyRevokeResult(MiniProgramAccessKeyRevokeResult result) {
    return <String>[
      'Revoked MiniProgram access key.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Key id: ${result.keyId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Policy key: ${result.policyKey}',
      'Revoked at UTC: ${result.revokedAtUtc}',
    ].join('\n');
  }

  String _formatAccessKeyRotateResult(MiniProgramAccessKeyRotateResult result) {
    return <String>[
      'Rotated MiniProgram access key.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Revoked key id: ${result.revokedKeyId}',
      'New key id: ${result.newKeyId}',
      'Access key: ${result.accessKey}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Policy key: ${result.policyKey}',
      'Rotated at UTC: ${result.rotatedAtUtc}',
    ].join('\n');
  }

  String _formatCloudAppListResult(MiniProgramCloudAppListResult result) {
    final lines = <String>[
      'Cloud mini-program apps:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
    ];
    if (result.apps.isEmpty) {
      lines.add('(no active apps)');
    } else {
      for (final app in result.apps) {
        lines.add(
          '- ${app.miniProgramId}: '
          '${app.latestVersion ?? 'unknown version'} '
          '(${app.catalogKey})',
        );
      }
    }
    return lines.join('\n');
  }

  String _formatCloudAppInfoResult(MiniProgramCloudAppInfoResult result) {
    return <String>[
      'Cloud mini-program app:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Catalog key: ${result.catalogKey}',
      if (result.catalog['latestVersion'] != null)
        'Latest version: ${result.catalog['latestVersion']}',
      if (result.releaseKey != null) 'Release key: ${result.releaseKey}',
      if (result.release?['artifacts'] case final artifacts?)
        'Artifacts: $artifacts',
      'Access policy key: ${result.accessPolicyKey ?? 'not found'}',
      'Access keys: ${result.activeAccessKeyCount} active / ${result.accessKeyCount} total',
    ].join('\n');
  }

  String _formatCloudAppDisableResult(MiniProgramCloudAppDisableResult result) {
    return <String>[
      result.dryRun
          ? 'Dry run: cloud mini-program app would be disabled.'
          : 'Disabled cloud mini-program app.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Catalog key: ${result.catalogKey}',
      'Disabled catalog key: ${result.disabledCatalogKey}',
      'Disabled at UTC: ${result.disabledAtUtc}',
      if (result.dryRun)
        'Re-run with --yes to remove the active catalog pointer.',
    ].join('\n');
  }

  String _formatCloudAppDeleteResult(MiniProgramCloudAppDeleteResult result) {
    final lines = <String>[
      result.dryRun
          ? 'Dry run: cloud mini-program app objects would be deleted.'
          : 'Deleted cloud mini-program app objects.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Object count: ${result.deletedKeys.length}',
      if (result.dryRun) 'Re-run with --yes to delete these objects.',
      'Objects:',
      ...result.deletedKeys.map((key) => '- $key'),
      'Completed at UTC: ${result.deletedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatPartnerPackageResult(MiniProgramPartnerPackageResult result) {
    return <String>[
      'Created MiniProgram partner handoff package.',
      'Package file: ${result.filePath}',
      'Mini-program: ${result.handoff.appId}',
      'Title: ${result.handoff.title}',
      'Access mode: ${result.handoff.accessMode}',
      'API base URL: ${result.handoff.apiBaseUri}',
      if (result.handoff.backendBaseUri != null)
        'Backend base URL: ${result.handoff.backendBaseUri}',
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
      'Access mode: ${result.accessMode}',
      'API base URL: ${result.apiBaseUri}',
      'Backend mode: ${result.backendMode}',
      if (result.backendBaseUri != null)
        'Backend base URL: ${result.backendBaseUri}',
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
      'Access mode: ${handoff.accessMode}',
      'API base URL: ${handoff.apiBaseUri}',
      if (handoff.backendBaseUri != null)
        'Backend base URL: ${handoff.backendBaseUri}',
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

  String _formatEmbeddedHostCloudConfigurationResult({
    required String projectRootPath,
    required String configurationPath,
    required EmbeddedHostCloudConfiguration configuration,
  }) {
    return <String>[
      'Configured embedded host app for cloud mini-program delivery.',
      'Project root: $projectRootPath',
      'Config file: $configurationPath',
      'Environment: ${configuration.environmentName}',
      'Provider: ${configuration.provider}',
      'Backend API base URL: ${configuration.backendApiBaseUrl}',
      'Configured at UTC: ${configuration.configuredAtUtc}',
      'Updated at UTC: ${configuration.updatedAtUtc}',
    ].join('\n');
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
        'Backend API base URL: generated runtime default'
      else
        'Backend API base URL: $backendApiBaseUrl',
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

    final activeCloudEnvironment = resolved.state.cloudEnvironmentNamed(
      resolved.state.activeEnvironment,
    );
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
      'Configured cloud environments: ${resolved.state.cloudEnvironments.length}',
      if (activeCloudEnvironment != null)
        'Active provider: ${activeCloudEnvironment.provider}',
      if (activeCloudEnvironment != null)
        ..._formatCloudEnvironmentValues(activeCloudEnvironment),
      if (resolved.state.activeEnvironment == 'cloud')
        'Active provider: legacy cloud alias (reconfigure to a named cloud environment)',
      'Initialized at UTC: ${resolved.state.initializedAtUtc}',
      'Updated at UTC: ${resolved.state.updatedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatEnvConfigureResult(
    CloudEnvironmentConfiguration environment,
    ResolvedLocalCliEnvironmentState resolved,
  ) {
    final lines = <String>[
      'Configured cloud environment: ${environment.name}',
      'Provider: ${environment.provider}',
      'Config scope: ${resolved.scope}',
      'Config root: ${resolved.rootPath}',
      'Config file: ${resolved.filePath}',
      ..._formatCloudEnvironmentValues(environment),
      'Configured at UTC: ${environment.configuredAtUtc}',
      'Updated at UTC: ${environment.updatedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatEnvListResult(ResolvedLocalCliEnvironmentState resolved) {
    final lines = <String>[
      'Configured environments:',
      '${resolved.state.activeEnvironment == 'local' ? '*' : '-'} local',
    ];
    for (final environment in resolved.state.cloudEnvironments) {
      lines.add(
        '${resolved.state.activeEnvironment == environment.name ? '*' : '-'} '
        '${environment.name} (${environment.provider})',
      );
    }
    if (resolved.state.activeEnvironment == 'cloud') {
      lines.add('- cloud (legacy alias)');
    }
    return lines.join('\n');
  }

  String _formatBackendStartResult(LocalBackendStartResult result) {
    final state = result.state;
    final lines = <String>[
      result.alreadyRunning
          ? 'Local backend was already running.'
          : 'Started local backend.',
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
      'Initialized local backend workspace.',
      'Backend root: ${result.backendRootPath}',
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
      return 'Local backend is not running. No backend.local.json state was found.';
    }

    final state = result.state!;
    final lines = <String>[
      'Local backend state found.',
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
      return 'No local backend state was found.';
    }
    if (result.clearedStaleState) {
      return 'Cleared stale local backend state. The recorded process was already gone.';
    }
    if (result.stopped) {
      return 'Stopped the local backend and cleared backend.local.json.';
    }
    return 'Local backend was not running.';
  }

  String _formatBackendResetResult(LocalBackendResetResult result) {
    final lines = <String>[
      'Removed ${result.removedPaths.length} tracked local backend artifact path(s).',
    ];
    if (result.removedPaths.isNotEmpty) {
      lines.addAll(result.removedPaths.map((path) => '- $path'));
    }
    return lines.join('\n');
  }
}
