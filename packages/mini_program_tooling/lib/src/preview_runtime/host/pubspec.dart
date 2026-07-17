import 'package:path/path.dart' as path;

const String previewSdkConstraint = '^0.5.13';
const String previewContractsConstraint = '^0.3.7';
const String previewHttpConstraint = '^1.5.0';
const String previewHostProjectName = 'mini_program_preview_host';

String buildPreviewHostPubspec({
  required String hostRootPath,
  required String? repoRootPath,
}) {
  final dependencies = <String>[
    'dependencies:',
    '  flutter:',
    '    sdk: flutter',
    '  http: $previewHttpConstraint',
    '  mini_program_sdk: $previewSdkConstraint',
    '  mini_program_contracts: $previewContractsConstraint',
  ];
  final dependencyOverrides = _miniProgramDependencyOverrideLines(
    hostRootPath: hostRootPath,
    repoRootPath: repoRootPath,
  );

  return [
    'name: $previewHostProjectName',
    'description: Managed preview host for mini_program_tooling.',
    "publish_to: 'none'",
    'version: 0.0.1+1',
    '',
    'environment:',
    '  sdk: ^3.10.0',
    '',
    ...dependencies,
    '',
    if (dependencyOverrides.isNotEmpty) ...<String>[...dependencyOverrides, ''],
    'flutter:',
    '  uses-material-design: true',
    '',
  ].join('\n');
}

List<String> _miniProgramDependencyOverrideLines({
  required String hostRootPath,
  required String? repoRootPath,
}) {
  if (repoRootPath == null) {
    return const <String>[];
  }

  final sdkPath = _yamlRelativePath(
    path.join(repoRootPath, 'packages', 'mini_program_sdk'),
    from: hostRootPath,
  );
  final contractsPath = _yamlRelativePath(
    path.join(repoRootPath, 'packages', 'mini_program_contracts'),
    from: hostRootPath,
  );
  return <String>[
    'dependency_overrides:',
    '  mini_program_sdk:',
    '    path: $sdkPath',
    '  mini_program_contracts:',
    '    path: $contractsPath',
  ];
}

String _yamlRelativePath(String targetPath, {required String from}) {
  final relativePath = path.relative(targetPath, from: from);
  return relativePath.replaceAll('\\', '/');
}
