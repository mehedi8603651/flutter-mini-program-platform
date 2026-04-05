import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

class DeliveryContext {
  const DeliveryContext({
    this.hostApp,
    this.sdkVersion,
    this.hostVersion,
    this.platform,
    this.locale,
    this.tenantId,
    this.pinnedVersion,
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
      hostVersion: _nullIfBlank(queryParameters['hostVersion']),
      platform: _nullIfBlank(queryParameters['platform']),
      locale: _nullIfBlank(queryParameters['locale']),
      tenantId: _nullIfBlank(queryParameters['tenantId']),
      pinnedVersion: _nullIfBlank(queryParameters['pinnedVersion']),
      capabilities: capabilities,
    );
  }

  final String? hostApp;
  final String? sdkVersion;
  final String? hostVersion;
  final String? platform;
  final String? locale;
  final String? tenantId;
  final String? pinnedVersion;
  final Set<String> capabilities;

  bool get hasContext =>
      hostApp != null ||
      sdkVersion != null ||
      hostVersion != null ||
      platform != null ||
      locale != null ||
      tenantId != null ||
      pinnedVersion != null ||
      capabilities.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hostApp': hostApp,
    'sdkVersion': sdkVersion,
    'hostVersion': hostVersion,
    'platform': platform,
    'locale': locale,
    'tenantId': tenantId,
    'pinnedVersion': pinnedVersion,
    'capabilities': capabilities.toList()..sort(),
  };
}

class DeliveryDecision {
  const DeliveryDecision({
    required this.selectionMode,
    required this.resolvedVersion,
    required this.deliveryContext,
    this.requestedPinnedVersion,
    this.matchedRuleId,
    this.matchedRule,
  });

  final String selectionMode;
  final String resolvedVersion;
  final Map<String, dynamic> deliveryContext;
  final String? requestedPinnedVersion;
  final String? matchedRuleId;
  final Map<String, dynamic>? matchedRule;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'selectionMode': selectionMode,
    'resolvedVersion': resolvedVersion,
    if (requestedPinnedVersion != null)
      'requestedPinnedVersion': requestedPinnedVersion,
    if (matchedRuleId != null) 'matchedRuleId': matchedRuleId,
    if (matchedRule != null) 'matchedRule': matchedRule,
    'deliveryContext': deliveryContext,
  };

  Map<String, dynamic> toErrorDetails() => <String, dynamic>{
    'selectionMode': selectionMode,
    'resolvedVersion': resolvedVersion,
    if (requestedPinnedVersion != null)
      'requestedPinnedVersion': requestedPinnedVersion,
    if (matchedRuleId != null) 'matchedRuleId': matchedRuleId,
    if (matchedRule != null) 'matchedRule': matchedRule,
    if (deliveryContext.isNotEmpty) 'deliveryContext': deliveryContext,
  };
}

class ManifestSelectionResult {
  const ManifestSelectionResult({
    required this.manifestJson,
    required this.version,
    required this.decision,
  });

  final Map<String, dynamic> manifestJson;
  final String version;
  final DeliveryDecision decision;
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

    final decision = _selectVersion(
      miniProgramId: miniProgramId,
      context: context,
      rolloutRules: rolloutRules,
    );

    late final Map<String, dynamic> manifestJson;
    try {
      manifestJson = await _readJsonMap(
        path.join(
          apiRootPath,
          'manifests',
          miniProgramId,
          'versions',
          '${decision.resolvedVersion}.json',
        ),
        notFoundMessage:
            'Manifest version "${decision.resolvedVersion}" for mini-program "$miniProgramId" was not found.',
      );
    } on ManifestSelectionException catch (error) {
      throw ManifestSelectionException(
        errorCode: error.errorCode,
        message: error.message,
        statusCode: error.statusCode,
        details: <String, dynamic>{
          ...error.details,
          ...decision.toErrorDetails(),
        },
      );
    }

    _validateSdkVersion(
      miniProgramId: miniProgramId,
      context: context,
      manifestJson: manifestJson,
      decision: decision,
    );
    _validateCapabilities(
      miniProgramId: miniProgramId,
      context: context,
      capabilityPolicy: capabilityPolicy,
      manifestJson: manifestJson,
      decision: decision,
    );

    return ManifestSelectionResult(
      manifestJson: manifestJson,
      version: decision.resolvedVersion,
      decision: decision,
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

  DeliveryDecision _selectVersion({
    required String miniProgramId,
    required DeliveryContext context,
    required _RolloutRules? rolloutRules,
  }) {
    final requestedPinnedVersion = context.pinnedVersion;
    if (requestedPinnedVersion != null) {
      return DeliveryDecision(
        selectionMode: 'pinned_version',
        resolvedVersion: requestedPinnedVersion,
        requestedPinnedVersion: requestedPinnedVersion,
        deliveryContext: context.toJson(),
      );
    }

    if (rolloutRules == null) {
      return DeliveryDecision(
        selectionMode: 'static_latest',
        resolvedVersion: _readStaticLatestVersion(miniProgramId),
        deliveryContext: context.toJson(),
      );
    }

    for (final rule in rolloutRules.rules) {
      if (!rule.matches(context)) {
        continue;
      }

      if (!rule.enabled) {
        throw ManifestSelectionException(
          errorCode: rule.hasHostRestriction
              ? 'host_not_enabled'
              : 'delivery_rule_disabled',
          message: _buildDisabledRuleMessage(
            miniProgramId: miniProgramId,
            context: context,
            rule: rule,
          ),
          details: <String, dynamic>{
            'miniProgramId': miniProgramId,
            'selectionMode': 'matched_rule',
            'resolvedVersion': rule.version,
            if (rule.id != null) 'matchedRuleId': rule.id,
            'deliveryContext': context.toJson(),
            'matchedRule': rule.toJson(),
          },
        );
      }

      return DeliveryDecision(
        selectionMode: 'matched_rule',
        resolvedVersion: rule.version,
        matchedRuleId: rule.id,
        matchedRule: rule.toJson(),
        deliveryContext: context.toJson(),
      );
    }

    final hostApp = context.hostApp;
    if (hostApp != null &&
        rolloutRules.hasHostRestrictedRules &&
        !rolloutRules.hasDeclaredRuleForHost(hostApp)) {
      throw ManifestSelectionException(
        errorCode: 'host_not_enabled',
        message:
            'Mini-program "$miniProgramId" is not enabled for host "$hostApp".',
        details: <String, dynamic>{
          'miniProgramId': miniProgramId,
          'hostApp': hostApp,
          'deliveryContext': context.toJson(),
        },
      );
    }

    return DeliveryDecision(
      selectionMode: 'default_version',
      resolvedVersion: rolloutRules.defaultVersion,
      deliveryContext: context.toJson(),
    );
  }

  String _buildDisabledRuleMessage({
    required String miniProgramId,
    required DeliveryContext context,
    required _DeliveryRule rule,
  }) {
    final hostApp = context.hostApp;
    if (hostApp != null && rule.hasHostRestriction) {
      return 'Mini-program "$miniProgramId" is disabled for host "$hostApp".';
    }

    return 'Mini-program "$miniProgramId" is disabled for the current delivery context.';
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
    required DeliveryDecision decision,
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
          ...decision.toErrorDetails(),
        },
      );
    }
  }

  void _validateCapabilities({
    required String miniProgramId,
    required DeliveryContext context,
    required _CapabilityPolicy? capabilityPolicy,
    required Map<String, dynamic> manifestJson,
    required DeliveryDecision decision,
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
          ...decision.toErrorDetails(),
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
        ...decision.toErrorDetails(),
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
  const _RolloutRules({required this.defaultVersion, required this.rules});

  factory _RolloutRules.fromJson(Map<String, dynamic> json) {
    final rawRules =
        json['rules'] as List<dynamic>? ??
        json['hostRules'] as List<dynamic>? ??
        const [];
    return _RolloutRules(
      defaultVersion: json['defaultVersion'] as String,
      rules: rawRules
          .map((value) => _DeliveryRule.fromJson(value as Map<String, dynamic>))
          .toList(),
    );
  }

  final String defaultVersion;
  final List<_DeliveryRule> rules;

  bool get hasHostRestrictedRules => rules.any((rule) => rule.hostApp != null);

  bool hasDeclaredRuleForHost(String hostApp) =>
      rules.any((rule) => rule.hostApp == hostApp);
}

class _DeliveryRule {
  const _DeliveryRule({
    this.id,
    this.hostApp,
    this.hostVersionRange,
    this.platform,
    this.locale,
    this.tenantId,
    required this.version,
    required this.enabled,
  });

  factory _DeliveryRule.fromJson(Map<String, dynamic> json) {
    return _DeliveryRule(
      id:
          _nullIfBlank(json['id']?.toString()) ??
          _nullIfBlank(json['ruleId']?.toString()),
      hostApp: _nullIfBlank(json['hostApp']?.toString()),
      hostVersionRange: _nullIfBlank(json['hostVersionRange']?.toString()),
      platform: _nullIfBlank(json['platform']?.toString()),
      locale: _nullIfBlank(json['locale']?.toString()),
      tenantId: _nullIfBlank(json['tenantId']?.toString()),
      version: json['version'] as String,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  final String? id;
  final String? hostApp;
  final String? hostVersionRange;
  final String? platform;
  final String? locale;
  final String? tenantId;
  final String version;
  final bool enabled;

  bool get hasHostRestriction => hostApp != null;

  bool matches(DeliveryContext context) {
    if (hostApp != null && context.hostApp != hostApp) {
      return false;
    }

    if (platform != null && context.platform != platform) {
      return false;
    }

    if (locale != null && !_localeMatches(context.locale, locale!)) {
      return false;
    }

    if (tenantId != null && context.tenantId != tenantId) {
      return false;
    }

    final rawHostVersionRange = hostVersionRange;
    if (rawHostVersionRange != null) {
      final requestedHostVersion = context.hostVersion;
      if (requestedHostVersion == null) {
        return false;
      }

      final parsedRequestedHostVersion = _parseRequestedHostVersion(
        requestedHostVersion,
      );
      final parsedRange = _parseHostVersionRange(rawHostVersionRange);
      if (!parsedRange.allows(parsedRequestedHostVersion)) {
        return false;
      }
    }

    return true;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'hostApp': hostApp,
    'hostVersionRange': hostVersionRange,
    'platform': platform,
    'locale': locale,
    'tenantId': tenantId,
    'version': version,
    'enabled': enabled,
  };
}

Version _parseRequestedHostVersion(String rawVersion) {
  try {
    return Version.parse(rawVersion);
  } on FormatException {
    throw ManifestSelectionException(
      errorCode: 'invalid_request',
      statusCode: HttpStatus.badRequest,
      message:
          'Request hostVersion "$rawVersion" is not a valid semantic version.',
      details: <String, dynamic>{'parameter': 'hostVersion'},
    );
  }
}

VersionConstraint _parseHostVersionRange(String rawRange) {
  try {
    return VersionConstraint.parse(rawRange);
  } on FormatException {
    throw ManifestSelectionException(
      errorCode: 'invalid_backend_json',
      statusCode: HttpStatus.internalServerError,
      message:
          'Rollout rule hostVersionRange "$rawRange" is not a valid semantic version range.',
    );
  }
}

bool _localeMatches(String? requestedLocale, String expectedLocale) {
  if (requestedLocale == null) {
    return false;
  }

  final normalizedRequested = requestedLocale.toLowerCase();
  final normalizedExpected = expectedLocale.toLowerCase();
  return normalizedRequested == normalizedExpected ||
      normalizedRequested.startsWith('$normalizedExpected-');
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
    case 'hostVersion':
      return context.hostVersion != null;
    case 'platform':
      return context.platform != null;
    case 'locale':
      return context.locale != null;
    case 'tenantId':
      return context.tenantId != null;
    case 'pinnedVersion':
      return context.pinnedVersion != null;
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
