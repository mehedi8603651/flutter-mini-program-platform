import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;

import '../delivery_validation.dart';
import 'json_reader.dart';
import 'shared_validation.dart';
import 'validation_context.dart';

const Set<String> _knownContextParameters = <String>{
  'hostApp',
  'sdkVersion',
  'hostVersion',
  'platform',
  'locale',
  'tenantId',
  'pinnedVersion',
  'capabilities',
};

Future<void> validateCapabilityPolicies({
  required DeliveryValidationContext context,
  required Map<String, MiniProgramManifest> authoredManifests,
}) async {
  final policiesRoot = Directory(
    path.join(context.backendApiRootPath, 'capability-policies'),
  );
  if (!await policiesRoot.exists()) {
    return;
  }

  final files = await policiesRoot
      .list()
      .where((entity) => entity is File)
      .cast<File>()
      .where((file) => path.extension(file.path) == '.json')
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final fileMiniProgramId = path.basenameWithoutExtension(file.path);
    if (context.miniProgramId != null &&
        fileMiniProgramId != context.miniProgramId) {
      continue;
    }

    final json = await readDeliveryJsonMap(file, context: context);
    if (json == null) {
      continue;
    }

    final declaredMiniProgramId = trimmedDeliveryValue(json['miniProgramId']);
    if (declaredMiniProgramId == null) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'capability_policy_missing_mini_program_id',
          path: context.relativePath(file.path),
          message: 'Capability policy must declare miniProgramId.',
        ),
      );
      continue;
    }

    if (declaredMiniProgramId != fileMiniProgramId) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'capability_policy_filename_mismatch',
          path: context.relativePath(file.path),
          message:
              'Capability policy file name "$fileMiniProgramId.json" must match miniProgramId "$declaredMiniProgramId".',
        ),
      );
    }

    if (!authoredManifests.containsKey(declaredMiniProgramId)) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.warning,
          code: 'capability_policy_missing_authored_manifest',
          path: context.relativePath(file.path),
          message:
              'Capability policy refers to "$declaredMiniProgramId", but no authored manifest was found under mini_programs/.',
        ),
      );
    }

    if (json.containsKey('requireContextForLatest') &&
        json['requireContextForLatest'] is! bool) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'capability_policy_invalid_require_context',
          path: context.relativePath(file.path),
          message: 'requireContextForLatest must be a boolean.',
        ),
      );
    }

    if (json.containsKey('enforceManifestCapabilities') &&
        json['enforceManifestCapabilities'] is! bool) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'capability_policy_invalid_enforce_capabilities',
          path: context.relativePath(file.path),
          message: 'enforceManifestCapabilities must be a boolean.',
        ),
      );
    }

    final rawRequiredQueryParameters = json['requiredQueryParameters'];
    if (rawRequiredQueryParameters is! List) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'capability_policy_required_query_parameters_not_list',
          path: context.relativePath(file.path),
          message: 'requiredQueryParameters must be a JSON list.',
        ),
      );
      continue;
    }

    final requiredQueryParameters = <String>[];
    final seenQueryParameters = <String>{};
    for (var index = 0; index < rawRequiredQueryParameters.length; index++) {
      final rawParameter = rawRequiredQueryParameters[index];
      final parameterPath =
          '${context.relativePath(file.path)}#requiredQueryParameters[$index]';
      final parameter = trimmedDeliveryValue(rawParameter);
      if (parameter == null) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_blank_required_parameter',
            path: parameterPath,
            message: 'requiredQueryParameters values must not be blank.',
          ),
        );
        continue;
      }

      requiredQueryParameters.add(parameter);
      if (!seenQueryParameters.add(parameter)) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_duplicate_required_parameter',
            path: parameterPath,
            message: 'requiredQueryParameters contains duplicate "$parameter".',
          ),
        );
      }

      if (!_knownContextParameters.contains(parameter)) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_unknown_required_parameter',
            path: parameterPath,
            message:
                '"$parameter" is not a supported delivery-context query parameter.',
          ),
        );
      }
    }

    final requireContextForLatest =
        json['requireContextForLatest'] as bool? ?? false;
    final enforceManifestCapabilities =
        json['enforceManifestCapabilities'] as bool? ?? false;

    if (requireContextForLatest && requiredQueryParameters.isEmpty) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'capability_policy_missing_required_parameters',
          path: context.relativePath(file.path),
          message:
              'requireContextForLatest=true requires at least one requiredQueryParameters value.',
        ),
      );
    }

    if (enforceManifestCapabilities &&
        !requiredQueryParameters.contains('capabilities')) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'capability_policy_missing_capabilities_parameter',
          path: context.relativePath(file.path),
          message:
              'enforceManifestCapabilities=true requires "capabilities" in requiredQueryParameters.',
        ),
      );
    }
  }
}
