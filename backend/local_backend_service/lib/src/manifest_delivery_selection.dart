import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

class DeliveryContext {
  const DeliveryContext({
    this.hostApp,
    this.sdkVersion,
    this.capabilities = const <String>{},
  });

  factory DeliveryContext.fromQueryParameters(
    Map<String, String> queryParameters,
  ) {
    final rawCapabilities = queryParameters['capabilities'] ?? '';
    final capabilities = rawCapabilities
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();

    return DeliveryContext(
      hostApp: _nullIfBlank(queryParameters['hostApp']),
      sdkVersion: _nullIfBlank(queryParameters['sdkVersion']),
      capabilities: capabilities,
    );
  }

  final String? hostApp;
  final String? sdkVersion;
  final Set<String> capabilities;

  bool get hasContext =>
      hostApp != null || sdkVersion != null || capabilities.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hostApp': hostApp,
    'sdkVersion': sdkVersion,
    'capabilities': capabilities.toList()..sort(),
  };
}

class ManifestSelectionResult {
  const ManifestSelectionResult({
    required this.manifestJson,
    required this.version,
  });

  final Map<String, dynamic> manifestJson;
  final String version;
}

class ManifestSelectionException implements Exception {
  const ManifestSelectionException({
    required this.errorCode,
    required this.message,
    this.statusCode = HttpStatus.preconditionFailed,
    this.details = const <String, dynamic>{},
  });

  final String errorCode;
  final String message;
  final int statusCode;
  final Map<String, dynamic> details;
}

class ManifestDeliverySelector {
  const ManifestDeliverySelector({required this.apiRootPath});

  final String apiRootPath;

  Future<ManifestSelectionResult> selectLatestManifest({
    required String miniProgramId,
    required DeliveryContext context,
  }) async {
    final rolloutRules = await _loadRolloutRules(miniProgramId);
    final capabilityPolicy = await _loadCapabilityPolicy(miniProgramId);

    if (capabilityPolicy?.requireContextForLatest == true) {
      _requireContext(
        miniProgramId: miniProgramId,
        context: context,
        capabilityPolicy: capabilityPolicy!,
      );
    }

    final selectedVersion = _selectVersion(
      miniProgramId: miniProgramId,
      context: context,
      rolloutRules: rolloutRules,
    );

    final manifestJson = await _readJsonMap(
      path.join(
        apiRootPath,
        'manifests',
        miniProgramId,
        'versions',
        '$selectedVersion.json',
      ),
      notFoundMessage:
          'Manifest version "$selectedVersion" for mini-program "$miniProgramId" was not found.',
    );

    _validateSdkVersion(
      miniProgramId: miniProgramId,
      context: context,
      manifestJson: manifestJson,
    );
    _validateCapabilities(
      miniProgramId: miniProgramId,
      context: context,
      capabilityPolicy: capabilityPolicy,
      manifestJson: manifestJson,
    );

    return ManifestSelectionResult(
      manifestJson: manifestJson,
      version: selectedVersion,
    );
  }

  Future<_RolloutRules?> _loadRolloutRules(String miniProgramId) async {
    final file = File(
      path.join(apiRootPath, 'rollout-rules', '$miniProgramId.json'),
    );
    if (!await file.exists()) {
      return null;
    }

    final json = await _readJsonMap(
      file.path,
      notFoundMessage: 'Rollout rules for "$miniProgramId" were not found.',
    );
    return _RolloutRules.fromJson(json);
  }

  Future<_CapabilityPolicy?> _loadCapabilityPolicy(String miniProgramId) async {
    final file = File(
      path.join(apiRootPath, 'capability-policies', '$miniProgramId.json'),
    );
    if (!await file.exists()) {
      return null;
    }

    final json = await _readJsonMap(
      file.path,
      notFoundMessage: 'Capability policy for "$miniProgramId" was not found.',
    );
    return _CapabilityPolicy.fromJson(json);
  }

  void _requireContext({
    required String miniProgramId,
    required DeliveryContext context,
    required _CapabilityPolicy capabilityPolicy,
  }) {
    final missingQueryParameters = capabilityPolicy.requiredQueryParameters
        .where((parameter) => !_hasRequiredParameter(parameter, context))
        .toList();

    if (missingQueryParameters.isEmpty) {
      return;
    }

    throw ManifestSelectionException(
      errorCode: 'manifest_context_required',
      statusCode: HttpStatus.badRequest,
      message:
          'Manifest context is required for "$miniProgramId": ${missingQueryParameters.join(', ')}.',
      details: <String, dynamic>{
        'miniProgramId': miniProgramId,
        'missingQueryParameters': missingQueryParameters,
      },
    );
  }

  String _selectVersion({
    required String miniProgramId,
    required DeliveryContext context,
    required _RolloutRules? rolloutRules,
  }) {
    if (rolloutRules == null) {
      return _readStaticLatestVersion(miniProgramId);
    }

    final hostApp = context.hostApp;
    if (hostApp == null) {
      return rolloutRules.defaultVersion;
    }

    for (final hostRule in rolloutRules.hostRules) {
      if (hostRule.hostApp == hostApp) {
        if (!hostRule.enabled) {
          throw ManifestSelectionException(
            errorCode: 'host_not_enabled',
            message:
                'Mini-program "$miniProgramId" is disabled for host "$hostApp".',
            details: <String, dynamic>{
              'miniProgramId': miniProgramId,
              'hostApp': hostApp,
            },
          );
        }
        return hostRule.version;
      }
    }

    throw ManifestSelectionException(
      errorCode: 'host_not_enabled',
      message:
          'Mini-program "$miniProgramId" is not enabled for host "$hostApp".',
      details: <String, dynamic>{
        'miniProgramId': miniProgramId,
        'hostApp': hostApp,
      },
    );
  }

  String _readStaticLatestVersion(String miniProgramId) {
    final file = File(
      path.join(apiRootPath, 'manifests', miniProgramId, 'latest.json'),
    );

    if (!file.existsSync()) {
      throw ManifestSelectionException(
        errorCode: 'artifact_not_found',
        statusCode: HttpStatus.notFound,
        message: 'Manifest for mini-program "$miniProgramId" was not found.',
      );
    }

    final rawJson = file.readAsStringSync();
    final json = jsonDecode(rawJson);
    if (json is! Map<String, dynamic>) {
      throw ManifestSelectionException(
        errorCode: 'invalid_backend_json',
        statusCode: HttpStatus.internalServerError,
        message:
            'Stored latest manifest JSON for "$miniProgramId" is malformed.',
      );
    }

    final version = _nullIfBlank(json['version']?.toString());
    if (version == null) {
      throw ManifestSelectionException(
        errorCode: 'invalid_backend_json',
        statusCode: HttpStatus.internalServerError,
        message:
            'Stored latest manifest for "$miniProgramId" does not contain a version.',
      );
    }

    return version;
  }

  void _validateSdkVersion({
    required String miniProgramId,
    required DeliveryContext context,
    required Map<String, dynamic> manifestJson,
  }) {
    final sdkVersion = context.sdkVersion;
    if (sdkVersion == null) {
      return;
    }

    final rawRange = _nullIfBlank(manifestJson['sdkVersionRange']?.toString());
    if (rawRange == null) {
      return;
    }

    final versionRange = VersionConstraint.parse(rawRange);
    final requestedVersion = Version.parse(sdkVersion);

    if (!versionRange.allows(requestedVersion)) {
      throw ManifestSelectionException(
        errorCode: 'incompatible_sdk_version',
        message:
            'Mini-program "$miniProgramId" requires SDK $rawRange, but host requested $sdkVersion.',
        details: <String, dynamic>{
          'miniProgramId': miniProgramId,
          'sdkVersionRange': rawRange,
          'requestedSdkVersion': sdkVersion,
        },
      );
    }
  }

  void _validateCapabilities({
    required String miniProgramId,
    required DeliveryContext context,
    required _CapabilityPolicy? capabilityPolicy,
    required Map<String, dynamic> manifestJson,
  }) {
    if (capabilityPolicy?.enforceManifestCapabilities != true) {
      return;
    }

    final requestedCapabilities = context.capabilities;
    if (requestedCapabilities.isEmpty) {
      throw ManifestSelectionException(
        errorCode: 'manifest_context_required',
        statusCode: HttpStatus.badRequest,
        message:
            'Manifest context is required for "$miniProgramId": capabilities.',
        details: <String, dynamic>{
          'miniProgramId': miniProgramId,
          'missingQueryParameters': const <String>['capabilities'],
        },
      );
    }

    final rawRequiredCapabilities =
        manifestJson['requiredCapabilities'] as List<dynamic>? ?? const [];
    final requiredCapabilities = rawRequiredCapabilities
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toSet();

    final missingCapabilities =
        requiredCapabilities
            .where((capability) => !requestedCapabilities.contains(capability))
            .toList()
          ..sort();

    if (missingCapabilities.isEmpty) {
      return;
    }

    throw ManifestSelectionException(
      errorCode: 'missing_capabilities',
      message:
          'Host app is missing required capabilities for "$miniProgramId": ${missingCapabilities.join(', ')}.',
      details: <String, dynamic>{
        'miniProgramId': miniProgramId,
        'missingCapabilities': missingCapabilities,
      },
    );
  }

  Future<Map<String, dynamic>> _readJsonMap(
    String filePath, {
    required String notFoundMessage,
  }) async {
    final file = File(path.normalize(path.absolute(filePath)));
    if (!await file.exists()) {
      throw ManifestSelectionException(
        errorCode: 'artifact_not_found',
        statusCode: HttpStatus.notFound,
        message: notFoundMessage,
      );
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw ManifestSelectionException(
        errorCode: 'invalid_backend_json',
        statusCode: HttpStatus.internalServerError,
        message: 'Stored backend JSON is malformed.',
      );
    }

    return decoded;
  }
}

class _RolloutRules {
  const _RolloutRules({required this.defaultVersion, required this.hostRules});

  factory _RolloutRules.fromJson(Map<String, dynamic> json) {
    final rawHostRules = json['hostRules'] as List<dynamic>? ?? const [];
    return _RolloutRules(
      defaultVersion: json['defaultVersion'] as String,
      hostRules: rawHostRules
          .map((value) => _HostRule.fromJson(value as Map<String, dynamic>))
          .toList(),
    );
  }

  final String defaultVersion;
  final List<_HostRule> hostRules;
}

class _HostRule {
  const _HostRule({
    required this.hostApp,
    required this.version,
    required this.enabled,
  });

  factory _HostRule.fromJson(Map<String, dynamic> json) {
    return _HostRule(
      hostApp: json['hostApp'] as String,
      version: json['version'] as String,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  final String hostApp;
  final String version;
  final bool enabled;
}

class _CapabilityPolicy {
  const _CapabilityPolicy({
    required this.requireContextForLatest,
    required this.enforceManifestCapabilities,
    required this.requiredQueryParameters,
  });

  factory _CapabilityPolicy.fromJson(Map<String, dynamic> json) {
    final rawRequiredQueryParameters =
        json['requiredQueryParameters'] as List<dynamic>? ?? const [];
    return _CapabilityPolicy(
      requireContextForLatest:
          json['requireContextForLatest'] as bool? ?? false,
      enforceManifestCapabilities:
          json['enforceManifestCapabilities'] as bool? ?? false,
      requiredQueryParameters: rawRequiredQueryParameters
          .map((value) => value.toString())
          .toList(),
    );
  }

  final bool requireContextForLatest;
  final bool enforceManifestCapabilities;
  final List<String> requiredQueryParameters;
}

bool _hasRequiredParameter(String parameter, DeliveryContext context) {
  switch (parameter) {
    case 'hostApp':
      return context.hostApp != null;
    case 'sdkVersion':
      return context.sdkVersion != null;
    case 'capabilities':
      return context.capabilities.isNotEmpty;
    default:
      return false;
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
