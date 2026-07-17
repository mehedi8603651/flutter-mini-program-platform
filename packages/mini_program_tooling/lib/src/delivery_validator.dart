import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;

import 'delivery_validation.dart';
import 'delivery_validation/authored_manifests.dart';
import 'delivery_validation/capability_policies.dart';
import 'delivery_validation/published_manifests.dart';
import 'delivery_validation/rollout_rules.dart';
import 'delivery_validation/secure_api_policies.dart';
import 'delivery_validation/validation_context.dart';

/// Validates authored and published mini-program delivery repositories.
class DeliveryRepositoryValidator {
  const DeliveryRepositoryValidator();

  Future<DeliveryValidationReport> validate({
    required String repoRootPath,
    String? authoredRepoRootPath,
    String? backendRootPath,
    String? miniProgramId,
    String? externalMiniProgramRootPath,
  }) async {
    final normalizedRepoRoot = path.normalize(path.absolute(repoRootPath));
    final normalizedAuthoredRepoRoot = path.normalize(
      path.absolute(authoredRepoRootPath ?? repoRootPath),
    );
    final normalizedBackendRoot = path.normalize(
      path.absolute(backendRootPath ?? repoRootPath),
    );
    final messages = <DeliveryValidationMessage>[];
    final miniProgramsRoot = Directory(
      path.join(normalizedAuthoredRepoRoot, 'mini_programs'),
    );
    final backendApiRoot = Directory(
      path.join(normalizedBackendRoot, 'backend', 'api'),
    );
    final context = DeliveryValidationContext(
      repoRootPath: normalizedRepoRoot,
      backendApiRootPath: backendApiRoot.path,
      miniProgramId: miniProgramId,
      messages: messages,
    );

    if (externalMiniProgramRootPath == null &&
        !await miniProgramsRoot.exists()) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'missing_mini_programs_root',
          path: context.relativePath(miniProgramsRoot.path),
          message: 'mini_programs/ was not found under the repo root.',
        ),
      );
    }

    if (!await backendApiRoot.exists()) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'missing_backend_api_root',
          path: context.relativePath(backendApiRoot.path),
          message:
              'Static artifact path backend/api/ was not found under the repo root.',
        ),
      );
    }

    if (messages.isNotEmpty) {
      return DeliveryValidationReport(
        repoRootPath: normalizedRepoRoot,
        messages: messages,
      );
    }

    final authoredManifests = <String, MiniProgramManifest>{};
    if (await miniProgramsRoot.exists()) {
      authoredManifests.addAll(
        await loadAuthoredManifests(
          context: context,
          miniProgramsRoot: miniProgramsRoot,
        ),
      );
    }

    if (externalMiniProgramRootPath != null &&
        externalMiniProgramRootPath.trim().isNotEmpty) {
      final externalManifest = await loadExternalAuthoredManifest(
        context: context,
        miniProgramRootPath: externalMiniProgramRootPath,
      );
      if (externalManifest != null) {
        authoredManifests[externalManifest.id] = externalManifest;
      }
    }

    final publishedVersionsByMiniProgram = await validatePublishedManifests(
      context: context,
    );

    await validateRolloutRules(
      context: context,
      authoredManifests: authoredManifests,
      publishedVersionsByMiniProgram: publishedVersionsByMiniProgram,
    );

    await validateCapabilityPolicies(
      context: context,
      authoredManifests: authoredManifests,
    );

    await validateSecureApiPolicies(
      context: context,
      authoredManifests: authoredManifests,
      publishedVersionsByMiniProgram: publishedVersionsByMiniProgram,
    );

    if (miniProgramId != null &&
        !authoredManifests.containsKey(miniProgramId) &&
        !publishedVersionsByMiniProgram.containsKey(miniProgramId)) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'mini_program_not_found',
          path: 'mini_programs/$miniProgramId',
          message:
              'No authored manifest or published static artifacts were found for "$miniProgramId".',
        ),
      );
    }

    return DeliveryValidationReport(
      repoRootPath: normalizedRepoRoot,
      messages: messages,
    );
  }
}
