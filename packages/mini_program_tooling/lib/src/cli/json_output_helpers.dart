import 'command_imports.dart';
import 'context.dart';
import 'miniprogram_cli_constants.dart';

extension CliJsonOutputHelpers on CliContext {
  String prettyJson(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  Map<String, Object?> doctorResultJson(MiniprogramDoctorResult result) {
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

  Map<String, Object?> capabilitiesJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'capabilities',
      'packageName': 'mini_program_tooling',
      'toolingVersion': miniProgramToolingVersion,
      'capabilityIds': cliCapabilityIds,
      'features': <String, bool>{
        'publisherApiMock': true,
        'publisherBackendContractInit': true,
        'publisherBackendContractValidate': true,
        'publisherBackendContractSmoke': true,
      },
      'commands': <String>[
        'embed init',
        'publish --target static',
        'publisher-api scaffold --template mock',
        'publisher-api contract init',
        'publisher-api contract validate',
        'publisher-api contract smoke',
        'publisher-api contract init',
        'publisher-api contract validate',
        'publisher-api contract smoke',
      ],
    };
  }

  Map<String, Object?> envStatusJson(
    ResolvedLocalCliEnvironmentState? resolved,
  ) {
    if (resolved == null) {
      return <String, Object?>{
        'schemaVersion': 1,
        'command': 'env status',
        'configured': false,
      };
    }
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'env status',
      'configured': true,
      'scope': resolved.scope,
      'rootPath': resolved.rootPath,
      'filePath': resolved.filePath,
      'repoRootPath': resolved.state.repoRootPath,
      'activeEnvironment': resolved.state.activeEnvironment,
      'initializedAtUtc': resolved.state.initializedAtUtc,
      'updatedAtUtc': resolved.state.updatedAtUtc,
    };
  }

  Map<String, Object?> publisherBackendStatusJson(
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
