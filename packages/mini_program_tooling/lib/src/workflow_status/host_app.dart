import 'dart:io';

import 'package:path/path.dart' as p;

import 'metadata.dart';

Future<Map<String, Object?>> inspectWorkflowHostApp(
  String workspacePath,
  Map<String, Object?> workspace,
) async {
  if (workspace['type'] != 'host_app') {
    return <String, Object?>{'detected': false};
  }

  final runtimeSetupPath = p.join(
    workspacePath,
    'lib',
    'mini_program',
    'mini_program_runtime_setup.dart',
  );
  final barrelPath = p.join(
    workspacePath,
    'lib',
    'mini_program',
    'mini_program.dart',
  );
  final hostSetupPath = p.join(
    workspacePath,
    'lib',
    'mini_program',
    'mini_program_host_setup.dart',
  );
  final launcherPath = p.join(
    workspacePath,
    'lib',
    'mini_program',
    'mini_program_launcher.dart',
  );
  final endpointPath = p.join(
    workspacePath,
    'lib',
    'mini_program',
    'mini_program_endpoints.dart',
  );
  final registryPath = p.join(
    workspacePath,
    'lib',
    'mini_program',
    'mini_program_registry.dart',
  );
  final policyPath = p.join(
    workspacePath,
    'lib',
    'mini_program',
    'mini_program_policies.json',
  );
  final policyResolverPath = p.join(
    workspacePath,
    'lib',
    'mini_program',
    'mini_program_policy_resolver.dart',
  );
  final pubspecPath = p.join(workspacePath, 'pubspec.yaml');
  final endpoints = await readWorkflowEndpointMetadata(File(endpointPath));
  final registryEntries = await readWorkflowRegistryMetadata(
    File(registryPath),
  );
  return <String, Object?>{
    'detected': true,
    'pubspecPath': pubspecPath,
    'barrelExists': await File(barrelPath).exists(),
    'barrelPath': barrelPath,
    'hostSetupExists': await File(hostSetupPath).exists(),
    'hostSetupPath': hostSetupPath,
    'runtimeSetupExists': await File(runtimeSetupPath).exists(),
    'runtimeSetupPath': runtimeSetupPath,
    'launcherExists': await File(launcherPath).exists(),
    'launcherPath': launcherPath,
    'endpointMapExists': await File(endpointPath).exists(),
    'endpointMapPath': endpointPath,
    'endpointCount': endpoints.length,
    'endpointAppIds': endpoints.keys.toList()..sort(),
    'registryExists': await File(registryPath).exists(),
    'registryPath': registryPath,
    'registryCount': registryEntries.length,
    'registryAppIds': registryEntries.keys.toList()..sort(),
    'policyExists': await File(policyPath).exists(),
    'policyPath': policyPath,
    'policyResolverExists': await File(policyResolverPath).exists(),
    'policyResolverPath': policyResolverPath,
    'registry': registryEntries.entries
        .map(
          (entry) => <String, Object?>{
            'appId': entry.key,
            'title': entry.value,
          },
        )
        .toList(),
    'endpoints': endpoints.entries
        .map(
          (entry) => <String, Object?>{
            'appId': entry.key,
            'apiBaseUri': entry.value['apiBaseUri'],
          },
        )
        .toList(),
  };
}
