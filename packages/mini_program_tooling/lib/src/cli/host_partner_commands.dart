import 'package:path/path.dart' as p;

import 'support.dart';

extension CliHostPartnerCommands on CliContext {
  StringSink get _stdout => stdoutSink;
  StringSink get _stderr => stderrSink;
  MiniProgramHostController get _hostController => dependencies.hostController;
  MiniProgramHostCapabilityInstaller get _hostCapabilityInstaller =>
      dependencies.hostCapabilityInstaller;
  MiniProgramPartnerHandoffController get _partnerHandoffController =>
      dependencies.partnerHandoffController;
  PublisherBackendContractController get _publisherBackendContractController =>
      dependencies.publisherBackendContractController;

  Future<int> runPartnerCommand(List<String> arguments) =>
      _runPartner(arguments);
  Future<int> runHostCommand(List<String> arguments) => _runHost(arguments);

  Future<int> _runPartner(List<String> arguments) async {
    if (isGroupHelpRequest(arguments)) {
      _stdout.writeln(partnerUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(partnerUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'package':
        return _runPartnerPackage(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown partner command: ${arguments.first}');
        _stderr.writeln(partnerUsage());
        return 64;
    }
  }

  Future<int> _runHost(List<String> arguments) async {
    if (isGroupHelpRequest(arguments)) {
      _stdout.writeln(hostUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(hostUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'run':
        return _runHostRun(arguments.sublist(1));
      case 'endpoint':
        return _runHostEndpoint(arguments.sublist(1));
      case 'capability':
        return _runHostCapability(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown host command: ${arguments.first}');
        _stderr.writeln(hostUsage());
        return 64;
    }
  }

  Future<int> _runHostCapability(List<String> arguments) async {
    if (isGroupHelpRequest(arguments)) {
      _stdout.writeln(hostCapabilityUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(hostCapabilityUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runHostCapabilityInit(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown host capability command: ${arguments.first}');
        _stderr.writeln(hostCapabilityUsage());
        return 64;
    }
  }

  Future<int> _runHostCapabilityInit(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'platform',
        help: 'Host platform to configure. Current value: android.',
      )
      ..addOption(
        'project-root',
        help:
            'Existing embedded Flutter host root. Defaults to the current directory.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Write a machine-readable result.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram host capability init location --platform android [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'host capability init expects exactly one capability name.',
      );
    }
    final platform = results.option('platform')?.trim() ?? '';
    if (platform.isEmpty) {
      throw const FormatException(
        'host capability init requires --platform android.',
      );
    }

    final result = await _hostCapabilityInstaller.initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath:
            results.option('project-root') ?? currentWorkingDirectory(),
        capability: results.rest.single,
        platform: platform,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(prettyJson(result.toJson()));
      return 0;
    }
    if (result.alreadyInstalled) {
      _stdout.writeln(
        'Android one-time approximate location support is already installed.',
      );
    } else {
      _stdout.writeln(
        'Installed Android one-time approximate location support.',
      );
      for (final path in result.createdPaths) {
        _stdout.writeln('Created: $path');
      }
      for (final path in result.updatedPaths) {
        _stdout.writeln('Updated: $path');
      }
    }
    _stdout.writeln(
      'No mini-program permission was accepted. Review '
      'lib/mini_program/mini_program_policies.json before enabling location '
      'for an app.',
    );
    return 0;
  }

  Future<int> _runHostEndpoint(List<String> arguments) async {
    if (isGroupHelpRequest(arguments)) {
      _stdout.writeln(hostEndpointUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(hostEndpointUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'add':
        return _runHostEndpointAdd(arguments.sublist(1));
      case 'import':
        return _runHostEndpointImport(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown host endpoint command: ${arguments.first}');
        _stderr.writeln(hostEndpointUsage());
        return 64;
    }
  }

  Future<int> _runPartnerPackage(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'title',
        help:
            'Human-readable mini-program title. Defaults to a title derived from the appId.',
      )
      ..addOption(
        'artifact-base-url',
        help: 'Mini-program static artifact base URL.',
      )
      ..addOption(
        'api-base-url',
        help:
            'Legacy alias for --artifact-base-url. Kept for existing scripts.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output JSON package path. Defaults to ./<mini-program-id>.partner.json.',
      )
      ..addOption(
        'mini-program-root',
        help:
            'Mini-program root used to detect publisher_backend.json. '
            'Defaults to the current directory.',
      )
      ..addOption(
        'env',
        help:
            'Ignored legacy option. Static artifact handoff requires --artifact-base-url.',
      )
      ..addOption(
        'root',
        help:
            'Directory that owns .mini_program/env.json. Defaults to discovery with global fallback.',
      )
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram partner package <mini-program-id> --artifact-base-url <url> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'partner package expects exactly one <mini-program-id>.',
      );
    }

    final appId = results.rest.single.trim();
    final apiBaseUrl = resolvePartnerPackageApiBaseUrl(
      explicitApiBaseUrl:
          results.option('artifact-base-url') ?? results.option('api-base-url'),
    );
    final miniProgramRootPath = p.normalize(
      p.absolute(
        results.option('mini-program-root') ?? currentWorkingDirectory(),
      ),
    );
    final publisherBackendContractPath = p.join(
      miniProgramRootPath,
      'publisher_backend.json',
    );
    var requestedPublisherApi = const <String, Object?>{};
    if (await File(publisherBackendContractPath).exists()) {
      final contract = await _publisherBackendContractController.readContract(
        contractPath: publisherBackendContractPath,
        allowLocalHttp: true,
      );
      if (contract.appId != appId) {
        throw FormatException(
          'publisher_backend.json appId "${contract.appId}" does not match '
          'partner package appId "$appId".',
        );
      }
      requestedPublisherApi = <String, Object?>{
        'enabled': true,
        'reason': contract.permissionReason,
        'contract': 'publisher_backend.json',
      };
    }
    final result = await _partnerHandoffController.createPackage(
      MiniProgramPartnerPackageRequest(
        appId: appId,
        title: results.option('title')?.trim().isNotEmpty == true
            ? results.option('title')!.trim()
            : defaultTitleForAppId(appId),
        artifactBaseUri: Uri.parse(apiBaseUrl),
        outputPath: results.option('output'),
        requestedPublisherApi: requestedPublisherApi,
      ),
    );
    _stdout.writeln(formatPartnerPackageResult(result));
    return 0;
  }

  Future<int> _runHostRun(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'device',
        abbr: 'd',
        help: 'Flutter device id such as chrome, windows, or emulator-5554.',
      )
      ..addOption(
        'project-root',
        help:
            'Existing Flutter app root containing pubspec.yaml and lib/. Defaults to the current directory.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram host run -d <device> [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final deviceId = results.option('device')?.trim() ?? '';
    if (deviceId.isEmpty) {
      throw const FormatException('host run requires -d <device>.');
    }

    final projectRootPath =
        results.option('project-root') ?? currentWorkingDirectory();
    await requireEmbeddedHostProject(projectRootPath);
    const backendApiBaseUrl = '';

    _stdout.writeln(
      formatHostRunStart(
        projectRootPath: p.normalize(p.absolute(projectRootPath)),
        deviceId: deviceId,
        environmentName: null,
        backendApiBaseUrl: backendApiBaseUrl,
      ),
    );
    final result = await _hostController.run(
      MiniProgramHostRunRequest(
        projectRootPath: projectRootPath,
        deviceId: deviceId,
        backendApiBaseUrl: backendApiBaseUrl,
      ),
    );
    return result.exitCode;
  }

  Future<int> _runHostEndpointAdd(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'project-root',
        help:
            'Existing Flutter app root containing pubspec.yaml and lib/. Defaults to the current directory.',
      )
      ..addOption(
        'artifact-base-url',
        help:
            'Mini-program static artifact base URL, for example https://cdn.example.com/app/.',
      )
      ..addOption(
        'api-base-url',
        help:
            'Legacy alias for --artifact-base-url. Kept for existing scripts.',
      )
      ..addOption(
        'title',
        help:
            'Display title to write into mini_program_registry.dart. Defaults to a title-cased appId.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Replace an unrecognized generated endpoint file.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram host endpoint add <mini-program-id> --artifact-base-url <url> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'host endpoint add expects exactly one <mini-program-id>.',
      );
    }
    final rawApiBaseUrl =
        (results.option('artifact-base-url') ?? results.option('api-base-url'))
            ?.trim() ??
        '';
    if (rawApiBaseUrl.isEmpty) {
      throw const FormatException(
        'host endpoint add requires --artifact-base-url <url>.',
      );
    }
    final apiBaseUri = Uri.tryParse(rawApiBaseUrl);
    if (apiBaseUri == null ||
        !apiBaseUri.hasScheme ||
        apiBaseUri.host.isEmpty) {
      throw FormatException(
        'host endpoint add expected an absolute --artifact-base-url, got: '
        '$rawApiBaseUrl',
      );
    }
    final projectRootPath =
        results.option('project-root') ?? currentWorkingDirectory();
    await requireEmbeddedHostProject(projectRootPath);
    final result = await _hostController.addEndpoint(
      MiniProgramHostEndpointAddRequest(
        projectRootPath: projectRootPath,
        appId: results.rest.single,
        title: results.option('title'),
        apiBaseUri: apiBaseUri,
        force: results.flag('force'),
      ),
    );
    _stdout.writeln(formatHostEndpointAddResult(result));
    return 0;
  }

  Future<int> _runHostEndpointImport(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'project-root',
        help:
            'Existing Flutter app root containing pubspec.yaml and lib/. Defaults to the current directory.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Replace an unrecognized generated endpoint file.',
      )
      ..addFlag(
        'accept-requested-policy',
        negatable: false,
        help: 'Update accepted host policy values from the latest handoff.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram host endpoint import <partner-package.json> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'host endpoint import expects exactly one <partner-package.json>.',
      );
    }

    final packagePath = results.rest.single;
    final handoff = await _partnerHandoffController.readPackage(packagePath);
    final projectRootPath =
        results.option('project-root') ?? currentWorkingDirectory();
    await requireEmbeddedHostProject(projectRootPath);
    final result = await _hostController.addEndpoint(
      MiniProgramHostEndpointAddRequest(
        projectRootPath: projectRootPath,
        appId: handoff.appId,
        title: handoff.title,
        apiBaseUri: handoff.artifactBaseUri,
        policySourcePath: packagePath,
        requestedCache: handoff.requestedCache,
        requestedPublisherApi: handoff.requestedPublisherApi,
        requestedPermissions: handoff.requestedPermissions,
        acceptRequestedPolicy: results.flag('accept-requested-policy'),
        force: results.flag('force'),
      ),
    );
    _stdout.writeln(
      formatHostEndpointImportResult(
        packagePath: p.normalize(p.absolute(packagePath)),
        handoff: handoff,
        endpointResult: result,
      ),
    );
    return 0;
  }
}
