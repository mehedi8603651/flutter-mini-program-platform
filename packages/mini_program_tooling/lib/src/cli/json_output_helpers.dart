part of '../miniprogram_cli.dart';

extension _MiniprogramCliJsonOutputHelpers on MiniprogramCli {
  String _prettyJson(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  Map<String, Object?> _doctorResultJson(MiniprogramDoctorResult result) {
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
    }
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'doctor',
      'hasErrors': result.hasErrors,
      'summary': <String, int>{
        'ok': okCount,
        'warning': warningCount,
        'error': errorCount,
        'skipped': skippedCount,
      },
      'checks': result.checks
          .map(
            (check) => <String, Object?>{
              'label': check.label,
              'status': check.status.name,
              'summary': check.summary,
              'detail': check.detail,
            },
          )
          .toList(),
    };
  }

  Map<String, Object?> _capabilitiesJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'capabilities',
      'packageName': 'mini_program_tooling',
      'toolingVersion': _miniProgramToolingVersion,
      'capabilityIds': _capabilityIds,
      'features': <String, bool>{
        'firebaseHostingPublish': true,
        'publisherApiMock': true,
        'publisherBackendContractInit': true,
        'publisherBackendContractValidate': true,
        'publisherBackendContractSmoke': true,
        'publisherBackendContractHandoff': true,
      },
      'commands': <String>[
        'embed init',
        'publish --target firebase-hosting',
        'publisher-api scaffold --template mock',
        'publisher-api contract init',
        'publisher-api contract validate',
        'publisher-api contract smoke',
        'publisher-api contract handoff',
        'publisher-api contract init',
        'publisher-api contract validate',
        'publisher-api contract smoke',
        'publisher-api contract handoff',
      ],
    };
  }

  Map<String, Object?> _envStatusJson(
    ResolvedLocalCliEnvironmentState? resolved,
  ) {
    if (resolved == null) {
      return <String, Object?>{
        'schemaVersion': 1,
        'command': 'env status',
        'configured': false,
      };
    }
    final activeCloudEnvironment = resolved.state.cloudEnvironmentNamed(
      resolved.state.activeEnvironment,
    );
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'env status',
      'configured': true,
      'scope': resolved.scope,
      'rootPath': resolved.rootPath,
      'filePath': resolved.filePath,
      'repoRootPath': resolved.state.repoRootPath,
      'activeEnvironment': resolved.state.activeEnvironment,
      'cloudEnvironmentCount': resolved.state.cloudEnvironments.length,
      'activeCloudEnvironment': activeCloudEnvironment == null
          ? null
          : _cloudEnvironmentJson(activeCloudEnvironment),
      'initializedAtUtc': resolved.state.initializedAtUtc,
      'updatedAtUtc': resolved.state.updatedAtUtc,
    };
  }

  Map<String, Object?> _cloudEnvironmentJson(
    CloudEnvironmentConfiguration environment,
  ) {
    return <String, Object?>{
      'name': environment.name,
      'provider': environment.provider,
      'values': Map<String, Object?>.from(environment.values),
      'configuredAtUtc': environment.configuredAtUtc,
      'updatedAtUtc': environment.updatedAtUtc,
    };
  }

  Map<String, Object?> _publisherBackendStatusJson(
    PublisherBackendStatusResult result,
  ) {
    final state = result.state;
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-api status',
      'hasState': result.hasState,
      'processAlive': result.processAlive,
      'healthy': result.healthy,
      'healthStatusCode': result.healthStatusCode,
      'healthError': result.healthError,
      if (state != null) ...<String, Object?>{
        'miniProgramRootPath': state.miniProgramRootPath,
        'backendRootPath': state.backendRootPath,
        'pid': state.pid,
        'port': state.port,
        'healthCheckUrl': state.healthCheckUrl,
        'urls': <String, Object?>{
          'desktopWeb': PublisherBackendUrlsResult(
            port: state.port,
          ).desktopBaseUrl,
          'androidEmulator': PublisherBackendUrlsResult(
            port: state.port,
          ).androidEmulatorBaseUrl,
          'androidUsb': PublisherBackendUrlsResult(
            port: state.port,
          ).androidUsbBaseUrl,
        },
      },
    };
  }
}
