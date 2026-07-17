import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

import '../delivery_validation.dart';
import 'json_reader.dart';
import 'shared_validation.dart';
import 'validation_context.dart';

Future<void> validateRolloutRules({
  required DeliveryValidationContext context,
  required Map<String, MiniProgramManifest> authoredManifests,
  required Map<String, Set<String>> publishedVersionsByMiniProgram,
}) async {
  final rolloutRoot = Directory(
    path.join(context.backendApiRootPath, 'rollout-rules'),
  );
  if (!await rolloutRoot.exists()) {
    return;
  }

  final files = await rolloutRoot
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
          code: 'rollout_missing_mini_program_id',
          path: context.relativePath(file.path),
          message: 'Rollout rules must declare miniProgramId.',
        ),
      );
      continue;
    }

    if (declaredMiniProgramId != fileMiniProgramId) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'rollout_filename_mismatch',
          path: context.relativePath(file.path),
          message:
              'Rollout file name "$fileMiniProgramId.json" must match miniProgramId "$declaredMiniProgramId".',
        ),
      );
    }

    if (!authoredManifests.containsKey(declaredMiniProgramId) &&
        !publishedVersionsByMiniProgram.containsKey(declaredMiniProgramId)) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'rollout_unknown_mini_program',
          path: context.relativePath(file.path),
          message:
              'Rollout rules refer to unknown mini-program "$declaredMiniProgramId".',
        ),
      );
    }

    final defaultVersion = trimmedDeliveryValue(json['defaultVersion']);
    if (defaultVersion == null) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'rollout_missing_default_version',
          path: context.relativePath(file.path),
          message: 'Rollout rules must declare defaultVersion.',
        ),
      );
    } else {
      validateDeliverySemanticVersion(
        context: context,
        value: defaultVersion,
        code: 'rollout_invalid_default_version',
        filePath: file.path,
        label: 'defaultVersion',
      );
      if (!hasPublishedDeliveryVersion(
        declaredMiniProgramId,
        defaultVersion,
        publishedVersionsByMiniProgram,
      )) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_default_version_not_published',
            path: context.relativePath(file.path),
            message:
                'defaultVersion "$defaultVersion" is not published for "$declaredMiniProgramId".',
          ),
        );
      }
    }

    final rawRules = json['rules'];
    if (rawRules is! List) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'rollout_rules_not_list',
          path: context.relativePath(file.path),
          message: 'Rollout rules must be a JSON list under "rules".',
        ),
      );
      continue;
    }

    final seenRuleIds = <String>{};
    for (var index = 0; index < rawRules.length; index++) {
      final rawRule = rawRules[index];
      final rulePath = '${context.relativePath(file.path)}#rules[$index]';
      if (rawRule is! Map) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_rule_not_object',
            path: rulePath,
            message: 'Each rollout rule must be a JSON object.',
          ),
        );
        continue;
      }

      final rule = rawRule.map((key, value) => MapEntry(key.toString(), value));
      final ruleId = trimmedDeliveryValue(rule['id']);
      if (ruleId == null) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_rule_missing_id',
            path: rulePath,
            message: 'Each rollout rule must declare a non-empty id.',
          ),
        );
      } else if (!seenRuleIds.add(ruleId)) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_rule_duplicate_id',
            path: rulePath,
            message: 'Rollout rule id "$ruleId" is duplicated.',
          ),
        );
      }

      final version = trimmedDeliveryValue(rule['version']);
      if (version == null) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_rule_missing_version',
            path: rulePath,
            message: 'Each rollout rule must declare a version.',
          ),
        );
      } else {
        validateDeliverySemanticVersion(
          context: context,
          value: version,
          code: 'rollout_rule_invalid_version',
          filePath: rulePath,
          label: 'version',
          isVirtualPath: true,
        );
        if (!hasPublishedDeliveryVersion(
          declaredMiniProgramId,
          version,
          publishedVersionsByMiniProgram,
        )) {
          context.messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'rollout_rule_version_not_published',
              path: rulePath,
              message:
                  'Rule version "$version" is not published for "$declaredMiniProgramId".',
            ),
          );
        }
      }

      final hostVersionRange = trimmedDeliveryValue(rule['hostVersionRange']);
      if (hostVersionRange != null) {
        try {
          VersionConstraint.parse(hostVersionRange);
        } on FormatException {
          context.messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'rollout_rule_invalid_host_version_range',
              path: rulePath,
              message:
                  'hostVersionRange "$hostVersionRange" is not a valid semantic version range.',
            ),
          );
        }
      }

      for (final field in const <String>[
        'hostApp',
        'platform',
        'locale',
        'tenantId',
      ]) {
        if (rule.containsKey(field) &&
            trimmedDeliveryValue(rule[field]) == null) {
          context.messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'rollout_rule_blank_$field',
              path: rulePath,
              message: '$field must not be blank when provided.',
            ),
          );
        }
      }

      if (rule.containsKey('enabled') && rule['enabled'] is! bool) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_rule_invalid_enabled',
            path: rulePath,
            message: 'enabled must be a boolean when provided.',
          ),
        );
      }
    }
  }
}
