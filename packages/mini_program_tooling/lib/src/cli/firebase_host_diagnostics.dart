part of '../miniprogram_cli.dart';

extension _MiniprogramCliFirebaseHostDiagnostics on MiniprogramCli {
  String _buildFirebaseHostEndpointCommandText({
    required String appId,
    required String title,
    required String deliveryApiBaseUrl,
    required String backendBaseUrl,
    required String accessMode,
    required String? accessKey,
    required String? hostProjectRootPath,
  }) {
    final arguments = <String>[
      'miniprogram',
      'host',
      'endpoint',
      'add',
      appId,
      if (hostProjectRootPath != null) ...<String>[
        '--project-root',
        hostProjectRootPath,
      ],
      '--title',
      title,
      '--api-base-url',
      deliveryApiBaseUrl,
      if (accessMode == 'public')
        '--public'
      else ...<String>['--access-key', accessKey ?? ''],
      '--backend-base-url',
      backendBaseUrl,
    ];
    return arguments.map(_quoteCommandArgument).join(' ');
  }

  String _buildHostEndpointImportCommandText(String packagePath) {
    return <String>[
      'miniprogram',
      'host',
      'endpoint',
      'import',
      packagePath,
    ].map(_quoteCommandArgument).join(' ');
  }

  Future<_HostEndpointReadiness> _inspectFirebaseHostEndpointReadiness({
    required String hostProjectRootPath,
    required String appId,
    required String deliveryApiBaseUrl,
    required String backendBaseUrl,
    required String accessMode,
  }) async {
    final endpointMapPath = p.join(
      hostProjectRootPath,
      'lib',
      'mini_program',
      'mini_program_endpoints.dart',
    );
    final endpointMapFile = File(endpointMapPath);
    if (!await endpointMapFile.exists()) {
      return _HostEndpointReadiness(
        ready: false,
        endpointFound: false,
        endpointMapPath: endpointMapPath,
        issues: const <String>[
          'Host endpoint map was not found. Run the generated host endpoint command from the host app root.',
        ],
      );
    }

    final source = await endpointMapFile.readAsString();
    final match = RegExp(
      r'// BEGIN MINI_PROGRAM_ENDPOINTS_JSON\s*// ([\s\S]*?)\s*// END MINI_PROGRAM_ENDPOINTS_JSON',
    ).firstMatch(source);
    if (match == null) {
      return _HostEndpointReadiness(
        ready: false,
        endpointFound: false,
        endpointMapPath: endpointMapPath,
        issues: const <String>[
          'Host endpoint map exists but does not contain managed endpoint metadata.',
        ],
      );
    }

    final decoded = jsonDecode(match.group(1)!.trim());
    if (decoded is! Map) {
      return _HostEndpointReadiness(
        ready: false,
        endpointFound: false,
        endpointMapPath: endpointMapPath,
        issues: const <String>['Host endpoint metadata was not a JSON object.'],
      );
    }
    final rawEndpoint = decoded[appId];
    if (rawEndpoint is! Map) {
      return _HostEndpointReadiness(
        ready: false,
        endpointFound: false,
        endpointMapPath: endpointMapPath,
        issues: <String>['Host endpoint for "$appId" was not found.'],
      );
    }

    final apiBaseUrl = rawEndpoint['apiBaseUri']?.toString();
    final endpointBackendBaseUrl = rawEndpoint['backendBaseUri']?.toString();
    final endpointAccessMode = rawEndpoint['accessMode']?.toString();
    final endpointBackendMode =
        rawEndpoint['backendMode']?.toString() ??
        ((endpointBackendBaseUrl?.trim().isEmpty ?? true) ? 'none' : 'remote');
    final issues = <String>[];
    if (!_urlsEquivalent(apiBaseUrl, deliveryApiBaseUrl)) {
      issues.add(
        'Delivery API base URL differs: expected "$deliveryApiBaseUrl", found "${apiBaseUrl ?? 'missing'}".',
      );
    }
    if (!_urlsEquivalent(endpointBackendBaseUrl, backendBaseUrl)) {
      issues.add(
        'Publisher backend base URL differs: expected "$backendBaseUrl", found "${endpointBackendBaseUrl ?? 'missing'}".',
      );
    }
    if (endpointAccessMode != accessMode) {
      issues.add(
        'Access mode differs: expected "$accessMode", found "${endpointAccessMode ?? 'missing'}".',
      );
    }
    if (endpointBackendMode != 'remote') {
      issues.add(
        'Backend mode differs: expected "remote", found "$endpointBackendMode".',
      );
    }
    return _HostEndpointReadiness(
      ready: issues.isEmpty,
      endpointFound: true,
      endpointMapPath: endpointMapPath,
      apiBaseUrl: apiBaseUrl,
      backendBaseUrl: endpointBackendBaseUrl,
      accessMode: endpointAccessMode,
      backendMode: endpointBackendMode,
      issues: issues,
    );
  }

  Future<_HostAuthReadiness> _inspectHostAuthReadiness({
    required String hostProjectRootPath,
  }) async {
    final runtimeSetupPath = p.join(
      hostProjectRootPath,
      'lib',
      'mini_program',
      'mini_program_runtime_setup.dart',
    );
    final runtimeSetupFile = File(runtimeSetupPath);
    if (!await runtimeSetupFile.exists()) {
      return _HostAuthReadiness(
        ready: false,
        runtimeSetupPath: runtimeSetupPath,
        authControllerConfigured: false,
        secureAuthControllerConfigured: false,
        disposeAuthControllerConfigured: false,
        issues: const <String>[
          'Host runtime setup was not found. Run `miniprogram embed init` in the Flutter host app first.',
        ],
      );
    }

    final source = await runtimeSetupFile.readAsString();
    final authControllerConfigured =
        source.contains('authController:') &&
        source.contains('MiniProgramAuthController');
    final secureAuthControllerConfigured = source.contains(
      'MiniProgramAuthController.secure',
    );
    final disposeAuthControllerConfigured = source.contains(
      'disposeAuthController: true',
    );
    final issues = <String>[];
    if (!authControllerConfigured) {
      issues.add(
        'Host runtime setup does not configure MiniProgramAuthController. Re-run `miniprogram embed init --project-root $hostProjectRootPath --force` with tooling 0.3.44 or add `authController: MiniProgramAuthController.secure()` to buildMiniProgramConfig.',
      );
    } else if (!secureAuthControllerConfigured) {
      issues.add(
        'Host runtime setup has an auth controller but does not use MiniProgramAuthController.secure() for persisted email auth sessions.',
      );
    }
    if (!disposeAuthControllerConfigured) {
      issues.add(
        'Host runtime setup should set `disposeAuthController: true` when it creates the auth controller.',
      );
    }

    return _HostAuthReadiness(
      ready: issues.isEmpty,
      runtimeSetupPath: runtimeSetupPath,
      authControllerConfigured: authControllerConfigured,
      secureAuthControllerConfigured: secureAuthControllerConfigured,
      disposeAuthControllerConfigured: disposeAuthControllerConfigured,
      issues: issues,
    );
  }

  bool _urlsEquivalent(String? first, String second) {
    if (first == null || first.trim().isEmpty) {
      return false;
    }
    return first.trim().replaceFirst(RegExp(r'/+$'), '') ==
        second.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  Future<void> _requireEmbeddedHostProject(String projectRootPath) async {
    final normalizedProjectRootPath = p.normalize(p.absolute(projectRootPath));
    final projectDirectory = Directory(normalizedProjectRootPath);
    if (!await projectDirectory.exists()) {
      throw MiniProgramHostException(
        'Flutter host project root does not exist: $normalizedProjectRootPath',
      );
    }

    final pubspecFile = File(p.join(normalizedProjectRootPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw MiniProgramHostException(
        'Flutter host project is missing pubspec.yaml: '
        '$normalizedProjectRootPath',
      );
    }

    final generatedRuntimeSetup = File(
      p.join(
        normalizedProjectRootPath,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    );
    if (!await generatedRuntimeSetup.exists()) {
      throw const MiniProgramHostException(
        'The generated mini-program embedding adapter was not found. Run '
        '`miniprogram embed init` in the host Flutter app first.',
      );
    }
  }

  String _requireBackendApiBaseUrlFromOutputs(
    MiniProgramCloudOutputsResult result,
  ) {
    final rawBackendApiBaseUrl = result.outputs['BackendApiBaseUrl'];
    if (rawBackendApiBaseUrl == null || rawBackendApiBaseUrl.trim().isEmpty) {
      throw const MiniProgramCloudException(
        'Cloud stack outputs did not include BackendApiBaseUrl.',
      );
    }
    return _normalizeAbsoluteUrl(rawBackendApiBaseUrl);
  }
}
