part of '../miniprogram_cli.dart';

extension _MiniprogramCliHostDiagnostics on MiniprogramCli {
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
