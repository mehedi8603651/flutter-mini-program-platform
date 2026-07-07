part of '../miniprogram_cli.dart';

extension _MiniprogramCliHostPartnerCommands on MiniprogramCli {
  Future<int> _runPartner(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_partnerUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_partnerUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'package':
        return _runPartnerPackage(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown partner command: ${arguments.first}');
        _stderr.writeln(_partnerUsage());
        return 64;
    }
  }

  Future<int> _runHost(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_hostUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_hostUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'run':
        return _runHostRun(arguments.sublist(1));
      case 'endpoint':
        return _runHostEndpoint(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown host command: ${arguments.first}');
        _stderr.writeln(_hostUsage());
        return 64;
    }
  }

  Future<int> _runHostEndpoint(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_hostEndpointUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_hostEndpointUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'add':
        return _runHostEndpointAdd(arguments.sublist(1));
      case 'import':
        return _runHostEndpointImport(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown host endpoint command: ${arguments.first}');
        _stderr.writeln(_hostEndpointUsage());
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
    final apiBaseUrl = _resolvePartnerPackageApiBaseUrl(
      explicitApiBaseUrl:
          results.option('artifact-base-url') ?? results.option('api-base-url'),
    );
    final result = await _partnerHandoffController.createPackage(
      MiniProgramPartnerPackageRequest(
        appId: appId,
        title: results.option('title')?.trim().isNotEmpty == true
            ? results.option('title')!.trim()
            : _defaultTitleForAppId(appId),
        artifactBaseUri: Uri.parse(apiBaseUrl),
        outputPath: results.option('output'),
      ),
    );
    _stdout.writeln(_formatPartnerPackageResult(result));
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
        results.option('project-root') ?? _currentWorkingDirectory();
    await _requireEmbeddedHostProject(projectRootPath);
    const backendApiBaseUrl = '';

    _stdout.writeln(
      _formatHostRunStart(
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
        'backend-base-url',
        help:
            'Optional publisher-owned business API base URL, for example https://publisher.example.com/api/.',
      )
      ..addFlag(
        'backend-local-mock',
        negatable: false,
        help: 'Use the local mock Publisher API at http://127.0.0.1:<port>/.',
      )
      ..addOption(
        'backend-local-mock-port',
        defaultsTo: '9090',
        help: 'Local mock Publisher API port used with --backend-local-mock.',
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
    final rawBackendBaseUrl = results.option('backend-base-url')?.trim() ?? '';
    final useLocalMockBackend = results.flag('backend-local-mock');
    if (useLocalMockBackend && rawBackendBaseUrl.isNotEmpty) {
      throw const FormatException(
        'host endpoint add cannot use both --backend-local-mock and '
        '--backend-base-url.',
      );
    }
    final rawLocalMockPort =
        results.option('backend-local-mock-port')?.trim() ?? '9090';
    final localMockPort = int.tryParse(rawLocalMockPort);
    if (useLocalMockBackend &&
        (localMockPort == null ||
            localMockPort <= 0 ||
            localMockPort > 65535)) {
      throw const FormatException(
        'host endpoint add --backend-local-mock-port must be 1-65535.',
      );
    }
    final backendBaseUri = useLocalMockBackend
        ? Uri.parse('http://127.0.0.1:$localMockPort/')
        : rawBackendBaseUrl.isEmpty
        ? null
        : Uri.tryParse(rawBackendBaseUrl);
    if (rawBackendBaseUrl.isNotEmpty &&
        (backendBaseUri == null ||
            !backendBaseUri.hasScheme ||
            backendBaseUri.host.isEmpty)) {
      throw FormatException(
        'host endpoint add expected an absolute --backend-base-url, got: '
        '$rawBackendBaseUrl',
      );
    }
    final projectRootPath =
        results.option('project-root') ?? _currentWorkingDirectory();
    await _requireEmbeddedHostProject(projectRootPath);
    final result = await _hostController.addEndpoint(
      MiniProgramHostEndpointAddRequest(
        projectRootPath: projectRootPath,
        appId: results.rest.single,
        title: results.option('title'),
        apiBaseUri: apiBaseUri,
        backendBaseUri: backendBaseUri,
        backendMode: useLocalMockBackend
            ? 'local_mock'
            : backendBaseUri == null
            ? 'none'
            : 'remote',
        force: results.flag('force'),
      ),
    );
    _stdout.writeln(_formatHostEndpointAddResult(result));
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
        results.option('project-root') ?? _currentWorkingDirectory();
    await _requireEmbeddedHostProject(projectRootPath);
    final result = await _hostController.addEndpoint(
      MiniProgramHostEndpointAddRequest(
        projectRootPath: projectRootPath,
        appId: handoff.appId,
        title: handoff.title,
        apiBaseUri: handoff.artifactBaseUri,
        policySourcePath: packagePath,
        requestedCache: handoff.requestedCache,
        acceptRequestedPolicy: results.flag('accept-requested-policy'),
        force: results.flag('force'),
      ),
    );
    _stdout.writeln(
      _formatHostEndpointImportResult(
        packagePath: p.normalize(p.absolute(packagePath)),
        handoff: handoff,
        endpointResult: result,
      ),
    );
    return 0;
  }
}
