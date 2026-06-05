import 'dart:convert';
import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

import 'delivery_validation.dart';

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

const Set<String> _knownHttpMethods = <String>{
  'DELETE',
  'GET',
  'PATCH',
  'POST',
  'PUT',
};

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

    if (externalMiniProgramRootPath == null &&
        !await miniProgramsRoot.exists()) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'missing_mini_programs_root',
          path: _relative(normalizedRepoRoot, miniProgramsRoot.path),
          message: 'mini_programs/ was not found under the repo root.',
        ),
      );
    }

    if (!await backendApiRoot.exists()) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'missing_backend_api_root',
          path: _relative(normalizedRepoRoot, backendApiRoot.path),
          message: 'backend/api/ was not found under the repo root.',
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
        await _loadAuthoredManifests(
          repoRootPath: normalizedRepoRoot,
          miniProgramsRoot: miniProgramsRoot,
          backendApiRootPath: backendApiRoot.path,
          miniProgramId: miniProgramId,
          messages: messages,
        ),
      );
    }

    if (externalMiniProgramRootPath != null &&
        externalMiniProgramRootPath.trim().isNotEmpty) {
      final externalManifest = await _loadExternalAuthoredManifest(
        repoRootPath: normalizedRepoRoot,
        miniProgramRootPath: externalMiniProgramRootPath,
        miniProgramId: miniProgramId,
        messages: messages,
      );
      if (externalManifest != null) {
        authoredManifests[externalManifest.id] = externalManifest;
      }
    }

    final publishedVersionsByMiniProgram = await _validatePublishedManifests(
      repoRootPath: normalizedRepoRoot,
      backendApiRootPath: backendApiRoot.path,
      miniProgramId: miniProgramId,
      messages: messages,
    );

    await _validateRolloutRules(
      repoRootPath: normalizedRepoRoot,
      backendApiRootPath: backendApiRoot.path,
      authoredManifests: authoredManifests,
      publishedVersionsByMiniProgram: publishedVersionsByMiniProgram,
      miniProgramId: miniProgramId,
      messages: messages,
    );

    await _validateCapabilityPolicies(
      repoRootPath: normalizedRepoRoot,
      backendApiRootPath: backendApiRoot.path,
      authoredManifests: authoredManifests,
      miniProgramId: miniProgramId,
      messages: messages,
    );

    await _validateSecureApiPolicies(
      repoRootPath: normalizedRepoRoot,
      backendApiRootPath: backendApiRoot.path,
      authoredManifests: authoredManifests,
      publishedVersionsByMiniProgram: publishedVersionsByMiniProgram,
      miniProgramId: miniProgramId,
      messages: messages,
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
              'No authored manifest or published backend artifacts were found for "$miniProgramId".',
        ),
      );
    }

    return DeliveryValidationReport(
      repoRootPath: normalizedRepoRoot,
      messages: messages,
    );
  }

  Future<Map<String, MiniProgramManifest>> _loadAuthoredManifests({
    required String repoRootPath,
    required Directory miniProgramsRoot,
    required String backendApiRootPath,
    required String? miniProgramId,
    required List<DeliveryValidationMessage> messages,
  }) async {
    final manifests = <String, MiniProgramManifest>{};
    final directories = await miniProgramsRoot
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    directories.sort((a, b) => a.path.compareTo(b.path));

    for (final directory in directories) {
      final folderName = path.basename(directory.path);
      if (miniProgramId != null && folderName != miniProgramId) {
        continue;
      }

      final manifestFile = File(path.join(directory.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        continue;
      }

      final manifestJson = await _readJsonMap(
        manifestFile,
        repoRootPath: repoRootPath,
        messages: messages,
      );
      if (manifestJson == null) {
        continue;
      }

      final manifest = _parseManifest(
        manifestJson,
        manifestFile.path,
        repoRootPath: repoRootPath,
        messages: messages,
      );
      if (manifest == null) {
        continue;
      }

      manifests[manifest.id] = manifest;

      if (manifest.id != folderName) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'manifest_directory_mismatch',
            path: _relative(repoRootPath, manifestFile.path),
            message:
                'Manifest id "${manifest.id}" must match mini-program folder "$folderName".',
          ),
        );
      }

      _validateManifestSemantics(
        manifest: manifest,
        manifestPath: manifestFile.path,
        repoRootPath: repoRootPath,
        messages: messages,
      );

      final publishedManifestFile = File(
        path.join(
          backendApiRootPath,
          'manifests',
          manifest.id,
          'versions',
          '${manifest.version}.json',
        ),
      );
      if (!await publishedManifestFile.exists()) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.warning,
            code: 'authored_manifest_not_published',
            path: _relative(repoRootPath, manifestFile.path),
            message:
                'No published backend manifest exists yet for version "${manifest.version}".',
          ),
        );
      }
    }

    return manifests;
  }

  Future<MiniProgramManifest?> _loadExternalAuthoredManifest({
    required String repoRootPath,
    required String miniProgramRootPath,
    required String? miniProgramId,
    required List<DeliveryValidationMessage> messages,
  }) async {
    final normalizedRootPath = path.normalize(
      path.absolute(miniProgramRootPath),
    );
    final rootDirectory = Directory(normalizedRootPath);
    if (!await rootDirectory.exists()) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'external_mini_program_root_missing',
          path: normalizedRootPath,
          message: 'Standalone mini-program root was not found.',
        ),
      );
      return null;
    }

    final manifestFile = File(path.join(normalizedRootPath, 'manifest.json'));
    if (!await manifestFile.exists()) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'external_manifest_missing',
          path: normalizedRootPath,
          message:
              'Standalone mini-program root does not contain manifest.json.',
        ),
      );
      return null;
    }

    final manifestJson = await _readJsonMap(
      manifestFile,
      repoRootPath: repoRootPath,
      messages: messages,
    );
    if (manifestJson == null) {
      return null;
    }

    final manifest = _parseManifest(
      manifestJson,
      manifestFile.path,
      repoRootPath: repoRootPath,
      messages: messages,
    );
    if (manifest == null) {
      return null;
    }

    if (miniProgramId != null && manifest.id != miniProgramId) {
      return null;
    }

    _validateManifestSemantics(
      manifest: manifest,
      manifestPath: manifestFile.path,
      repoRootPath: repoRootPath,
      messages: messages,
    );

    return manifest;
  }

  Future<Map<String, Set<String>>> _validatePublishedManifests({
    required String repoRootPath,
    required String backendApiRootPath,
    required String? miniProgramId,
    required List<DeliveryValidationMessage> messages,
  }) async {
    final publishedVersionsByMiniProgram = <String, Set<String>>{};
    final manifestsRoot = Directory(path.join(backendApiRootPath, 'manifests'));
    if (!await manifestsRoot.exists()) {
      return publishedVersionsByMiniProgram;
    }

    final miniProgramDirectories = await manifestsRoot
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    miniProgramDirectories.sort((a, b) => a.path.compareTo(b.path));

    for (final miniProgramDirectory in miniProgramDirectories) {
      final currentMiniProgramId = path.basename(miniProgramDirectory.path);
      if (miniProgramId != null && currentMiniProgramId != miniProgramId) {
        continue;
      }

      final publishedVersions = <String>{};
      publishedVersionsByMiniProgram[currentMiniProgramId] = publishedVersions;

      final latestFile = File(
        path.join(miniProgramDirectory.path, 'latest.json'),
      );
      if (await latestFile.exists()) {
        final latestManifest = await _validatePublishedManifestFile(
          manifestFile: latestFile,
          expectedMiniProgramId: currentMiniProgramId,
          expectedVersion: null,
          repoRootPath: repoRootPath,
          backendApiRootPath: backendApiRootPath,
          messages: messages,
        );
        if (latestManifest != null) {
          publishedVersions.add(latestManifest.version);
        }
      } else {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.warning,
            code: 'latest_manifest_missing',
            path: _relative(repoRootPath, miniProgramDirectory.path),
            message:
                'Published manifest directory does not contain latest.json.',
          ),
        );
      }

      final versionsDirectory = Directory(
        path.join(miniProgramDirectory.path, 'versions'),
      );
      if (!await versionsDirectory.exists()) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'manifest_versions_missing',
            path: _relative(repoRootPath, miniProgramDirectory.path),
            message: 'Published manifest directory does not contain versions/.',
          ),
        );
        continue;
      }

      final versionFiles = await versionsDirectory
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .where((file) => path.extension(file.path) == '.json')
          .toList();
      versionFiles.sort((a, b) => a.path.compareTo(b.path));

      for (final manifestFile in versionFiles) {
        final expectedVersion = path.basenameWithoutExtension(
          manifestFile.path,
        );
        final manifest = await _validatePublishedManifestFile(
          manifestFile: manifestFile,
          expectedMiniProgramId: currentMiniProgramId,
          expectedVersion: expectedVersion,
          repoRootPath: repoRootPath,
          backendApiRootPath: backendApiRootPath,
          messages: messages,
        );
        if (manifest != null) {
          publishedVersions.add(manifest.version);
        }
      }
    }

    return publishedVersionsByMiniProgram;
  }

  Future<MiniProgramManifest?> _validatePublishedManifestFile({
    required File manifestFile,
    required String expectedMiniProgramId,
    required String? expectedVersion,
    required String repoRootPath,
    required String backendApiRootPath,
    required List<DeliveryValidationMessage> messages,
  }) async {
    final manifestJson = await _readJsonMap(
      manifestFile,
      repoRootPath: repoRootPath,
      messages: messages,
    );
    if (manifestJson == null) {
      return null;
    }

    final manifest = _parseManifest(
      manifestJson,
      manifestFile.path,
      repoRootPath: repoRootPath,
      messages: messages,
    );
    if (manifest == null) {
      return null;
    }

    _validateManifestSemantics(
      manifest: manifest,
      manifestPath: manifestFile.path,
      repoRootPath: repoRootPath,
      messages: messages,
    );

    if (manifest.id != expectedMiniProgramId) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'published_manifest_id_mismatch',
          path: _relative(repoRootPath, manifestFile.path),
          message:
              'Published manifest id "${manifest.id}" must match backend directory "$expectedMiniProgramId".',
        ),
      );
    }

    if (expectedVersion != null && manifest.version != expectedVersion) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'published_manifest_version_mismatch',
          path: _relative(repoRootPath, manifestFile.path),
          message:
              'Published manifest version "${manifest.version}" must match filename "$expectedVersion.json".',
        ),
      );
    }

    final entryScreenFile = File(
      path.join(
        backendApiRootPath,
        'screens',
        manifest.id,
        manifest.version,
        '${manifest.entry}.json',
      ),
    );
    if (!await entryScreenFile.exists()) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'entry_screen_missing',
          path: _relative(repoRootPath, manifestFile.path),
          message:
              'Entry screen "${manifest.entry}.json" was not found under backend/api/screens/${manifest.id}/${manifest.version}/.',
        ),
      );
    }

    return manifest;
  }

  Future<void> _validateRolloutRules({
    required String repoRootPath,
    required String backendApiRootPath,
    required Map<String, MiniProgramManifest> authoredManifests,
    required Map<String, Set<String>> publishedVersionsByMiniProgram,
    required String? miniProgramId,
    required List<DeliveryValidationMessage> messages,
  }) async {
    final rolloutRoot = Directory(
      path.join(backendApiRootPath, 'rollout-rules'),
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
      if (miniProgramId != null && fileMiniProgramId != miniProgramId) {
        continue;
      }

      final json = await _readJsonMap(
        file,
        repoRootPath: repoRootPath,
        messages: messages,
      );
      if (json == null) {
        continue;
      }

      final declaredMiniProgramId = _trimmed(json['miniProgramId']);
      if (declaredMiniProgramId == null) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_missing_mini_program_id',
            path: _relative(repoRootPath, file.path),
            message: 'Rollout rules must declare miniProgramId.',
          ),
        );
        continue;
      }

      if (declaredMiniProgramId != fileMiniProgramId) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_filename_mismatch',
            path: _relative(repoRootPath, file.path),
            message:
                'Rollout file name "$fileMiniProgramId.json" must match miniProgramId "$declaredMiniProgramId".',
          ),
        );
      }

      if (!authoredManifests.containsKey(declaredMiniProgramId) &&
          !publishedVersionsByMiniProgram.containsKey(declaredMiniProgramId)) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_unknown_mini_program',
            path: _relative(repoRootPath, file.path),
            message:
                'Rollout rules refer to unknown mini-program "$declaredMiniProgramId".',
          ),
        );
      }

      final defaultVersion = _trimmed(json['defaultVersion']);
      if (defaultVersion == null) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_missing_default_version',
            path: _relative(repoRootPath, file.path),
            message: 'Rollout rules must declare defaultVersion.',
          ),
        );
      } else {
        _validateSemanticVersion(
          value: defaultVersion,
          code: 'rollout_invalid_default_version',
          filePath: file.path,
          repoRootPath: repoRootPath,
          messages: messages,
          label: 'defaultVersion',
        );
        if (!_hasPublishedVersion(
          declaredMiniProgramId,
          defaultVersion,
          publishedVersionsByMiniProgram,
        )) {
          messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'rollout_default_version_not_published',
              path: _relative(repoRootPath, file.path),
              message:
                  'defaultVersion "$defaultVersion" is not published for "$declaredMiniProgramId".',
            ),
          );
        }
      }

      final rawRules = json['rules'];
      if (rawRules is! List) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'rollout_rules_not_list',
            path: _relative(repoRootPath, file.path),
            message: 'Rollout rules must be a JSON list under "rules".',
          ),
        );
        continue;
      }

      final seenRuleIds = <String>{};
      for (var index = 0; index < rawRules.length; index++) {
        final rawRule = rawRules[index];
        final rulePath = '${_relative(repoRootPath, file.path)}#rules[$index]';
        if (rawRule is! Map) {
          messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'rollout_rule_not_object',
              path: rulePath,
              message: 'Each rollout rule must be a JSON object.',
            ),
          );
          continue;
        }

        final rule = rawRule.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final ruleId = _trimmed(rule['id']);
        if (ruleId == null) {
          messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'rollout_rule_missing_id',
              path: rulePath,
              message: 'Each rollout rule must declare a non-empty id.',
            ),
          );
        } else if (!seenRuleIds.add(ruleId)) {
          messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'rollout_rule_duplicate_id',
              path: rulePath,
              message: 'Rollout rule id "$ruleId" is duplicated.',
            ),
          );
        }

        final version = _trimmed(rule['version']);
        if (version == null) {
          messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'rollout_rule_missing_version',
              path: rulePath,
              message: 'Each rollout rule must declare a version.',
            ),
          );
        } else {
          _validateSemanticVersion(
            value: version,
            code: 'rollout_rule_invalid_version',
            filePath: rulePath,
            repoRootPath: repoRootPath,
            messages: messages,
            label: 'version',
            isVirtualPath: true,
          );
          if (!_hasPublishedVersion(
            declaredMiniProgramId,
            version,
            publishedVersionsByMiniProgram,
          )) {
            messages.add(
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

        final hostVersionRange = _trimmed(rule['hostVersionRange']);
        if (hostVersionRange != null) {
          try {
            VersionConstraint.parse(hostVersionRange);
          } on FormatException {
            messages.add(
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
          if (rule.containsKey(field) && _trimmed(rule[field]) == null) {
            messages.add(
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
          messages.add(
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

  Future<void> _validateCapabilityPolicies({
    required String repoRootPath,
    required String backendApiRootPath,
    required Map<String, MiniProgramManifest> authoredManifests,
    required String? miniProgramId,
    required List<DeliveryValidationMessage> messages,
  }) async {
    final policiesRoot = Directory(
      path.join(backendApiRootPath, 'capability-policies'),
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
      if (miniProgramId != null && fileMiniProgramId != miniProgramId) {
        continue;
      }

      final json = await _readJsonMap(
        file,
        repoRootPath: repoRootPath,
        messages: messages,
      );
      if (json == null) {
        continue;
      }

      final declaredMiniProgramId = _trimmed(json['miniProgramId']);
      if (declaredMiniProgramId == null) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_missing_mini_program_id',
            path: _relative(repoRootPath, file.path),
            message: 'Capability policy must declare miniProgramId.',
          ),
        );
        continue;
      }

      if (declaredMiniProgramId != fileMiniProgramId) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_filename_mismatch',
            path: _relative(repoRootPath, file.path),
            message:
                'Capability policy file name "$fileMiniProgramId.json" must match miniProgramId "$declaredMiniProgramId".',
          ),
        );
      }

      if (!authoredManifests.containsKey(declaredMiniProgramId)) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.warning,
            code: 'capability_policy_missing_authored_manifest',
            path: _relative(repoRootPath, file.path),
            message:
                'Capability policy refers to "$declaredMiniProgramId", but no authored manifest was found under mini_programs/.',
          ),
        );
      }

      if (json.containsKey('requireContextForLatest') &&
          json['requireContextForLatest'] is! bool) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_invalid_require_context',
            path: _relative(repoRootPath, file.path),
            message: 'requireContextForLatest must be a boolean.',
          ),
        );
      }

      if (json.containsKey('enforceManifestCapabilities') &&
          json['enforceManifestCapabilities'] is! bool) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_invalid_enforce_capabilities',
            path: _relative(repoRootPath, file.path),
            message: 'enforceManifestCapabilities must be a boolean.',
          ),
        );
      }

      final rawRequiredQueryParameters = json['requiredQueryParameters'];
      if (rawRequiredQueryParameters is! List) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_required_query_parameters_not_list',
            path: _relative(repoRootPath, file.path),
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
            '${_relative(repoRootPath, file.path)}#requiredQueryParameters[$index]';
        final parameter = _trimmed(rawParameter);
        if (parameter == null) {
          messages.add(
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
          messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'capability_policy_duplicate_required_parameter',
              path: parameterPath,
              message:
                  'requiredQueryParameters contains duplicate "$parameter".',
            ),
          );
        }

        if (!_knownContextParameters.contains(parameter)) {
          messages.add(
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
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_missing_required_parameters',
            path: _relative(repoRootPath, file.path),
            message:
                'requireContextForLatest=true requires at least one requiredQueryParameters value.',
          ),
        );
      }

      if (enforceManifestCapabilities &&
          !requiredQueryParameters.contains('capabilities')) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'capability_policy_missing_capabilities_parameter',
            path: _relative(repoRootPath, file.path),
            message:
                'enforceManifestCapabilities=true requires "capabilities" in requiredQueryParameters.',
          ),
        );
      }
    }
  }

  Future<void> _validateSecureApiPolicies({
    required String repoRootPath,
    required String backendApiRootPath,
    required Map<String, MiniProgramManifest> authoredManifests,
    required Map<String, Set<String>> publishedVersionsByMiniProgram,
    required String? miniProgramId,
    required List<DeliveryValidationMessage> messages,
  }) async {
    final policiesRoot = Directory(
      path.join(backendApiRootPath, 'secure-api-policies'),
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
      final json = await _readJsonMap(
        file,
        repoRootPath: repoRootPath,
        messages: messages,
      );
      if (json == null) {
        continue;
      }

      final endpoint = _trimmed(json['endpoint']);
      if (endpoint == null) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'secure_api_policy_missing_endpoint',
            path: _relative(repoRootPath, file.path),
            message: 'Secure API policy must declare endpoint.',
          ),
        );
      } else {
        if (!_isSafeEndpointPath(endpoint)) {
          messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'secure_api_policy_invalid_endpoint',
              path: _relative(repoRootPath, file.path),
              message:
                  'Endpoint "$endpoint" must use safe path segments without leading or trailing slashes.',
            ),
          );
        }

        final expectedFilePolicyId = endpoint.replaceAll('/', '_');
        if (expectedFilePolicyId != filePolicyId) {
          messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'secure_api_policy_filename_mismatch',
              path: _relative(repoRootPath, file.path),
              message:
                  'Secure API policy file name "$filePolicyId.json" must match endpoint "$endpoint" as "$expectedFilePolicyId.json".',
            ),
          );
        }
      }

      _validateStringListField(
        json: json,
        fieldName: 'allowedMethods',
        filePath: file.path,
        repoRootPath: repoRootPath,
        messages: messages,
        required: true,
        transform: (value) => value.toUpperCase(),
        validator: (value) => _knownHttpMethods.contains(value),
        invalidValueMessage: (value) =>
            '"$value" is not a supported HTTP method.',
      );

      _validateStringListField(
        json: json,
        fieldName: 'allowedHosts',
        filePath: file.path,
        repoRootPath: repoRootPath,
        messages: messages,
        required: true,
      );

      _validateStringListField(
        json: json,
        fieldName: 'blockedUserIds',
        filePath: file.path,
        repoRootPath: repoRootPath,
        messages: messages,
        required: false,
      );

      _validateStringListField(
        json: json,
        fieldName: 'expiredAccessTokenPrefixes',
        filePath: file.path,
        repoRootPath: repoRootPath,
        messages: messages,
        required: false,
      );

      final allowedSources = _validateStringListField(
        json: json,
        fieldName: 'allowedSources',
        filePath: file.path,
        repoRootPath: repoRootPath,
        messages: messages,
        required: true,
      );

      for (final source in allowedSources) {
        if (miniProgramId != null && source != miniProgramId) {
          continue;
        }
        if (!knownMiniProgramIds.contains(source)) {
          messages.add(
            DeliveryValidationMessage(
              severity: ValidationSeverity.error,
              code: 'secure_api_policy_unknown_source',
              path: _relative(repoRootPath, file.path),
              message:
                  'allowedSources contains "$source", but no authored manifest or published backend artifacts were found for it.',
            ),
          );
        }
      }

      final minimumMessageLength = json['minimumMessageLength'];
      if (minimumMessageLength == null) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'secure_api_policy_missing_minimum_message_length',
            path: _relative(repoRootPath, file.path),
            message: 'Secure API policy must declare minimumMessageLength.',
          ),
        );
      } else if (minimumMessageLength is! int || minimumMessageLength <= 0) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'secure_api_policy_invalid_minimum_message_length',
            path: _relative(repoRootPath, file.path),
            message: 'minimumMessageLength must be a positive integer.',
          ),
        );
      }
    }
  }

  void _validateManifestSemantics({
    required MiniProgramManifest manifest,
    required String manifestPath,
    required String repoRootPath,
    required List<DeliveryValidationMessage> messages,
  }) {
    _validateSemanticVersion(
      value: manifest.version,
      code: 'manifest_invalid_version',
      filePath: manifestPath,
      repoRootPath: repoRootPath,
      messages: messages,
      label: 'version',
    );

    _validateSemanticVersion(
      value: manifest.contractVersion,
      code: 'manifest_invalid_contract_version',
      filePath: manifestPath,
      repoRootPath: repoRootPath,
      messages: messages,
      label: 'contractVersion',
    );

    if (!manifest.sdkVersionRange.isValid) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'manifest_invalid_sdk_version_range',
          path: _relative(repoRootPath, manifestPath),
          message:
              'sdkVersionRange "${manifest.sdkVersionRange.value}" is not a valid semantic version range.',
        ),
      );
    }

    if (manifest.entry.trim().isEmpty) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'manifest_blank_entry',
          path: _relative(repoRootPath, manifestPath),
          message: 'entry must not be blank.',
        ),
      );
    }

    if (manifest.fallback?.strategy == MiniProgramFallbackStrategy.hostRoute &&
        (manifest.fallback?.route == null ||
            manifest.fallback!.route!.trim().isEmpty)) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'manifest_host_route_fallback_missing_route',
          path: _relative(repoRootPath, manifestPath),
          message:
              'fallback.route is required when fallback.strategy is hostRoute.',
        ),
      );
    }

    if (manifest.requiresCapability(CapabilityIds.secureApi) &&
        manifest.cachePolicy.entryScreen.mode != MiniProgramCacheMode.noCache) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'secure_api_entry_screen_must_not_cache',
          path: _relative(repoRootPath, manifestPath),
          message:
              'Mini-programs requiring secure_api must set entryScreen cache mode to noCache.',
        ),
      );
    }
  }

  MiniProgramManifest? _parseManifest(
    Map<String, dynamic> manifestJson,
    String manifestPath, {
    required String repoRootPath,
    required List<DeliveryValidationMessage> messages,
  }) {
    try {
      return MiniProgramManifest.fromJson(manifestJson);
    } catch (error) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'manifest_parse_failed',
          path: _relative(repoRootPath, manifestPath),
          message: 'Manifest could not be parsed: $error',
        ),
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readJsonMap(
    File file, {
    required String repoRootPath,
    required List<DeliveryValidationMessage> messages,
  }) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'json_object_required',
            path: _relative(repoRootPath, file.path),
            message: 'Expected a top-level JSON object.',
          ),
        );
        return null;
      }

      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on FileSystemException catch (error) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'file_read_failed',
          path: _relative(repoRootPath, file.path),
          message: 'Could not read file: $error',
        ),
      );
    } on FormatException catch (error) {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'json_decode_failed',
          path: _relative(repoRootPath, file.path),
          message: 'Invalid JSON: ${error.message}',
        ),
      );
    }

    return null;
  }

  void _validateSemanticVersion({
    required String value,
    required String code,
    required String filePath,
    required String repoRootPath,
    required List<DeliveryValidationMessage> messages,
    required String label,
    bool isVirtualPath = false,
  }) {
    try {
      Version.parse(value);
    } on FormatException {
      messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: code,
          path: isVirtualPath ? filePath : _relative(repoRootPath, filePath),
          message: '$label "$value" is not a valid semantic version.',
        ),
      );
    }
  }

  bool _hasPublishedVersion(
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

  List<String> _validateStringListField({
    required Map<String, dynamic> json,
    required String fieldName,
    required String filePath,
    required String repoRootPath,
    required List<DeliveryValidationMessage> messages,
    required bool required,
    String Function(String value)? transform,
    bool Function(String value)? validator,
    String Function(String value)? invalidValueMessage,
  }) {
    final rawValue = json[fieldName];
    final relativeFilePath = _relative(repoRootPath, filePath);
    if (rawValue == null) {
      if (required) {
        messages.add(
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
      messages.add(
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
      final normalizedValue = _trimmed(rawValue[index]);
      final itemPath = '$relativeFilePath#$fieldName[$index]';
      if (normalizedValue == null) {
        messages.add(
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
        messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: '${fieldName}_duplicate',
            path: itemPath,
            message: '$fieldName contains duplicate "$transformedValue".',
          ),
        );
      }

      if (validator != null && !validator(transformedValue)) {
        messages.add(
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
      messages.add(
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

  bool _isSafeEndpointPath(String value) {
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
          !_isSafePathToken(normalizedSegment)) {
        return false;
      }
    }

    return true;
  }

  bool _isSafePathToken(String value) =>
      RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value);

  String _relative(String repoRootPath, String targetPath) =>
      path.relative(targetPath, from: repoRootPath).replaceAll('\\', '/');

  String? _trimmed(Object? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
