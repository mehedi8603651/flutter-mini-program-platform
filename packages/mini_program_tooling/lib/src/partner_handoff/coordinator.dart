import 'files.dart';
import 'handoff.dart';
import 'models.dart';

Future<MiniProgramPartnerPackageResult> createMiniProgramPartnerPackage(
  MiniProgramPartnerPackageRequest request,
) async {
  final handoff = MiniProgramPartnerHandoff(
    schemaVersion: request.schemaVersion,
    appId: request.appId.trim(),
    title: request.title.trim(),
    artifactBaseUri: request.artifactBaseUri,
    apiBaseUri: request.apiBaseUri,
    generatedAtUtc: (request.generatedAtUtc ?? DateTime.now().toUtc())
        .toIso8601String(),
    requestedCache: request.requestedCache,
    requestedPublisherApi: request.requestedPublisherApi,
    requestedPermissions: request.requestedPermissions,
  );
  final outputPath = resolvePartnerHandoffOutputPath(
    outputPath: request.outputPath,
    appId: handoff.appId,
  );
  await writePartnerHandoffFile(outputPath: outputPath, handoff: handoff);
  return MiniProgramPartnerPackageResult(
    filePath: outputPath,
    handoff: handoff,
  );
}
