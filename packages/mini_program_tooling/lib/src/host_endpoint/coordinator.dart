import 'dart:io';

import 'package:path/path.dart' as p;

import 'endpoint_file.dart';
import 'models.dart';
import 'policy_document.dart';
import 'policy_resolver.dart';
import 'records.dart';
import 'registry_file.dart';
import 'validation.dart';

Future<MiniProgramHostEndpointAddResult> addMiniProgramHostEndpoint(
  MiniProgramHostEndpointAddRequest request,
) async {
  final projectRootPath = await validateHostProject(
    request.projectRootPath,
    requireRuntimeSetup: false,
  );
  validateHostIdentifier(request.appId, 'appId');
  validateHostEndpointUri(request.apiBaseUri);

  final miniProgramDirectory = Directory(
    p.join(projectRootPath, 'lib', 'mini_program'),
  );
  await miniProgramDirectory.create(recursive: true);
  final file = File(
    p.join(miniProgramDirectory.path, 'mini_program_endpoints.dart'),
  );
  final registryFile = File(
    p.join(miniProgramDirectory.path, 'mini_program_registry.dart'),
  );
  final policyFile = File(
    p.join(miniProgramDirectory.path, 'mini_program_policies.json'),
  );
  final policyResolverFile = File(
    p.join(miniProgramDirectory.path, 'mini_program_policy_resolver.dart'),
  );

  final created = !await file.exists();
  final existingEndpointSource = created ? null : await file.readAsString();
  final existingEndpoints = created
      ? <String, HostEndpointRecord>{}
      : parseGeneratedHostEndpoints(existingEndpointSource!, file.path);
  if (!created &&
      !isManagedHostEndpointFile(existingEndpointSource!) &&
      !request.force) {
    throw MiniProgramHostException(
      'Existing endpoint file is not managed by miniprogram tooling: '
      '${file.path}. Pass --force to replace it.',
    );
  }
  final updated = existingEndpoints.containsKey(request.appId);
  final endpoints = request.force && !created
      ? <String, HostEndpointRecord>{...existingEndpoints}
      : existingEndpoints;
  endpoints[request.appId] = HostEndpointRecord(
    apiBaseUri: normalizeHostEndpointUri(request.apiBaseUri),
  );

  final registryCreated = !await registryFile.exists();
  final existingRegistrySource = registryCreated
      ? null
      : await registryFile.readAsString();
  final existingRegistry = registryCreated
      ? <String, HostRegistryRecord>{}
      : parseGeneratedHostRegistry(existingRegistrySource!, registryFile.path);
  if (!registryCreated &&
      !isManagedHostRegistryFile(existingRegistrySource!) &&
      !request.force) {
    throw MiniProgramHostException(
      'Existing registry file is not managed by miniprogram tooling: '
      '${registryFile.path}. Pass --force to replace it.',
    );
  }
  final registry = <String, HostRegistryRecord>{...existingRegistry};
  for (final appId in endpoints.keys) {
    registry.putIfAbsent(
      appId,
      () => newHostRegistryRecord(
        appId: appId,
        title: titleFromHostAppId(appId),
        existing: registry,
      ),
    );
  }
  final title = normalizeHostTitle(
    request.title ??
        registry[request.appId]?.title ??
        titleFromHostAppId(request.appId),
  );
  registry[request.appId] = HostRegistryRecord(
    appId: request.appId,
    title: title,
    constantName:
        registry[request.appId]?.constantName ??
        uniqueHostRegistryFieldName(
          preferred: dartFieldNameFromHostAppId(request.appId),
          appId: request.appId,
          existing: registry,
        ),
  );

  final policies = await upsertHostPolicyFile(
    policyFile: policyFile,
    appId: request.appId,
    sourcePath: request.policySourcePath,
    requestedCache: request.requestedCache,
    requestedPublisherApi: request.requestedPublisherApi,
    requestedPermissions: request.requestedPermissions,
    acceptRequestedPolicy: request.acceptRequestedPolicy,
    forceAcceptedPolicy: request.force,
  );
  await policyResolverFile.writeAsString(buildHostPolicyResolverFile(policies));
  await registryFile.writeAsString(buildHostRegistryFile(registry));
  await file.writeAsString(buildHostEndpointFile(endpoints, registry));

  return MiniProgramHostEndpointAddResult(
    projectRootPath: projectRootPath,
    filePath: file.path,
    registryFilePath: registryFile.path,
    policyFilePath: policyFile.path,
    policyResolverFilePath: policyResolverFile.path,
    appId: request.appId,
    title: title,
    apiBaseUri: request.apiBaseUri,
    endpointCount: endpoints.length,
    registryCount: registry.length,
    created: created,
    updated: updated,
  );
}
