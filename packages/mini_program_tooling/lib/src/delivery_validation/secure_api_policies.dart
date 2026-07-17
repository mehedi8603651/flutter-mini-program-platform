import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;

import '../delivery_validation.dart';
import 'json_reader.dart';
import 'shared_validation.dart';
import 'validation_context.dart';

const Set<String> _knownHttpMethods = <String>{
  'DELETE',
  'GET',
  'PATCH',
  'POST',
  'PUT',
};

Future<void> validateSecureApiPolicies({
  required DeliveryValidationContext context,
  required Map<String, MiniProgramManifest> authoredManifests,
  required Map<String, Set<String>> publishedVersionsByMiniProgram,
}) async {
  final policiesRoot = Directory(
    path.join(context.backendApiRootPath, 'secure-api-policies'),
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

  final knownMiniProgramIds = <String>{
    ...authoredManifests.keys,
    ...publishedVersionsByMiniProgram.keys,
  };

  for (final file in files) {
    final filePolicyId = path.basenameWithoutExtension(file.path);
    final json = await readDeliveryJsonMap(file, context: context);
    if (json == null) {
      continue;
    }

    final endpoint = trimmedDeliveryValue(json['endpoint']);
    if (endpoint == null) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'secure_api_policy_missing_endpoint',
          path: context.relativePath(file.path),
          message: 'Secure API policy must declare endpoint.',
        ),
      );
    } else {
      if (!isSafeDeliveryEndpointPath(endpoint)) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'secure_api_policy_invalid_endpoint',
            path: context.relativePath(file.path),
            message:
                'Endpoint "$endpoint" must use safe path segments without leading or trailing slashes.',
          ),
        );
      }

      final expectedFilePolicyId = endpoint.replaceAll('/', '_');
      if (expectedFilePolicyId != filePolicyId) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'secure_api_policy_filename_mismatch',
            path: context.relativePath(file.path),
            message:
                'Secure API policy file name "$filePolicyId.json" must match endpoint "$endpoint" as "$expectedFilePolicyId.json".',
          ),
        );
      }
    }

    validateDeliveryStringListField(
      context: context,
      json: json,
      fieldName: 'allowedMethods',
      filePath: file.path,
      required: true,
      transform: (value) => value.toUpperCase(),
      validator: (value) => _knownHttpMethods.contains(value),
      invalidValueMessage: (value) =>
          '"$value" is not a supported HTTP method.',
    );

    validateDeliveryStringListField(
      context: context,
      json: json,
      fieldName: 'allowedHosts',
      filePath: file.path,
      required: true,
    );

    validateDeliveryStringListField(
      context: context,
      json: json,
      fieldName: 'blockedUserIds',
      filePath: file.path,
      required: false,
    );

    validateDeliveryStringListField(
      context: context,
      json: json,
      fieldName: 'expiredAccessTokenPrefixes',
      filePath: file.path,
      required: false,
    );

    final allowedSources = validateDeliveryStringListField(
      context: context,
      json: json,
      fieldName: 'allowedSources',
      filePath: file.path,
      required: true,
    );

    for (final source in allowedSources) {
      if (context.miniProgramId != null && source != context.miniProgramId) {
        continue;
      }
      if (!knownMiniProgramIds.contains(source)) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'secure_api_policy_unknown_source',
            path: context.relativePath(file.path),
            message:
                'allowedSources contains "$source", but no authored manifest or published static artifacts were found for it.',
          ),
        );
      }
    }

    final minimumMessageLength = json['minimumMessageLength'];
    if (minimumMessageLength == null) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'secure_api_policy_missing_minimum_message_length',
          path: context.relativePath(file.path),
          message: 'Secure API policy must declare minimumMessageLength.',
        ),
      );
    } else if (minimumMessageLength is! int || minimumMessageLength <= 0) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'secure_api_policy_invalid_minimum_message_length',
          path: context.relativePath(file.path),
          message: 'minimumMessageLength must be a positive integer.',
        ),
      );
    }
  }
}
