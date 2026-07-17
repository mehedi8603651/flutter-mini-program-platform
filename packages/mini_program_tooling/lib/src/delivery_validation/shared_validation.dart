import 'package:pub_semver/pub_semver.dart';

import '../delivery_validation.dart';
import 'validation_context.dart';

void validateDeliverySemanticVersion({
  required DeliveryValidationContext context,
  required String value,
  required String code,
  required String filePath,
  required String label,
  bool isVirtualPath = false,
}) {
  try {
    Version.parse(value);
  } on FormatException {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: code,
        path: isVirtualPath ? filePath : context.relativePath(filePath),
        message: '$label "$value" is not a valid semantic version.',
      ),
    );
  }
}

bool hasPublishedDeliveryVersion(
  String miniProgramId,
  String version,
  Map<String, Set<String>> publishedVersionsByMiniProgram,
) {
  final versions = publishedVersionsByMiniProgram[miniProgramId];
  if (versions == null) {
    return false;
  }
  return versions.contains(version);
}

List<String> validateDeliveryStringListField({
  required DeliveryValidationContext context,
  required Map<String, dynamic> json,
  required String fieldName,
  required String filePath,
  required bool required,
  String Function(String value)? transform,
  bool Function(String value)? validator,
  String Function(String value)? invalidValueMessage,
}) {
  final rawValue = json[fieldName];
  final relativeFilePath = context.relativePath(filePath);
  if (rawValue == null) {
    if (required) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: '${fieldName}_missing',
          path: relativeFilePath,
          message: '$fieldName must be present.',
        ),
      );
    }
    return const <String>[];
  }

  if (rawValue is! List) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: '${fieldName}_not_list',
        path: relativeFilePath,
        message: '$fieldName must be a JSON list.',
      ),
    );
    return const <String>[];
  }

  final values = <String>[];
  final seenValues = <String>{};
  for (var index = 0; index < rawValue.length; index++) {
    final normalizedValue = trimmedDeliveryValue(rawValue[index]);
    final itemPath = '$relativeFilePath#$fieldName[$index]';
    if (normalizedValue == null) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: '${fieldName}_blank',
          path: itemPath,
          message: '$fieldName values must not be blank.',
        ),
      );
      continue;
    }

    final transformedValue = transform == null
        ? normalizedValue
        : transform(normalizedValue);
    values.add(transformedValue);

    if (!seenValues.add(transformedValue)) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: '${fieldName}_duplicate',
          path: itemPath,
          message: '$fieldName contains duplicate "$transformedValue".',
        ),
      );
    }

    if (validator != null && !validator(transformedValue)) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: '${fieldName}_invalid_value',
          path: itemPath,
          message:
              invalidValueMessage?.call(transformedValue) ??
              '$fieldName contains invalid value "$transformedValue".',
        ),
      );
    }
  }

  if (required && values.isEmpty) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: '${fieldName}_empty',
        path: relativeFilePath,
        message: '$fieldName must contain at least one value.',
      ),
    );
  }

  return values;
}

bool isSafeDeliveryEndpointPath(String value) {
  if (value.startsWith('/') || value.endsWith('/')) {
    return false;
  }

  final segments = value.split('/');
  if (segments.isEmpty) {
    return false;
  }

  for (final segment in segments) {
    final normalizedSegment = segment.trim();
    if (normalizedSegment.isEmpty ||
        normalizedSegment == '.' ||
        normalizedSegment == '..' ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(normalizedSegment)) {
      return false;
    }
  }

  return true;
}

String? trimmedDeliveryValue(Object? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}
