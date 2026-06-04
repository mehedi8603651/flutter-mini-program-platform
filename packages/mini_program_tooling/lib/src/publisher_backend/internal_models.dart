part of '../publisher_backend_starter.dart';

class _PublisherBackendHealth {
  const _PublisherBackendHealth({
    required this.healthy,
    this.statusCode,
    this.error,
  });

  final bool healthy;
  final int? statusCode;
  final String? error;
}

class _FirebaseRedemptionVerification {
  const _FirebaseRedemptionVerification({required this.verified, this.error});

  final bool verified;
  final String? error;
}

class _FirebaseAuthSmokePostResult {
  const _FirebaseAuthSmokePostResult({
    required this.route,
    this.idToken,
    this.refreshToken,
  });

  final PublisherBackendFirebaseSmokeRouteResult route;
  final String? idToken;
  final String? refreshToken;
}

class _PublisherBackendAwsSeedData {
  const _PublisherBackendAwsSeedData({
    required this.home,
    required this.session,
    required this.coupons,
  });

  final Map<String, Object?> home;
  final Map<String, Object?> session;
  final List<Map<String, Object?>> coupons;
}

class _PublisherBackendFirebaseSeedData {
  const _PublisherBackendFirebaseSeedData({
    required this.home,
    required this.session,
    required this.coupons,
  });

  final Map<String, Object?> home;
  final Map<String, Object?> session;
  final List<Map<String, Object?>> coupons;
}

class _FirestoreSeedRecord {
  const _FirestoreSeedRecord({
    required this.documentPath,
    required this.document,
  });

  final String documentPath;
  final Map<String, Object?> document;
}

class _FirestoreImportRecord {
  const _FirestoreImportRecord({
    required this.documentPath,
    required this.data,
  });

  final String documentPath;
  final Map<String, Object?> data;
}

class _FirebasePublicInvokerResult {
  const _FirebasePublicInvokerResult({
    required this.configured,
    required this.changed,
  });

  final bool configured;
  final bool changed;
}

class _FirebaseAuthTokenCreatorResult {
  const _FirebaseAuthTokenCreatorResult({
    required this.configured,
    required this.changed,
    required this.serviceAccountEmail,
  });

  final bool configured;
  final bool changed;
  final String serviceAccountEmail;
}

class _PublisherBackendAwsDataImportPlan {
  const _PublisherBackendAwsDataImportPlan({
    required this.items,
    required this.appRecordCount,
    required this.redemptionCount,
    required this.skippedRedemptionCount,
  });

  final List<Map<String, Object?>> items;
  final int appRecordCount;
  final int redemptionCount;
  final int skippedRedemptionCount;
}

class _PublisherBackendFirebaseDataImportPlan {
  const _PublisherBackendFirebaseDataImportPlan({
    required this.records,
    required this.appRecordCount,
    required this.redemptionCount,
    required this.skippedRedemptionCount,
  });

  final List<_FirestoreImportRecord> records;
  final int appRecordCount;
  final int redemptionCount;
  final int skippedRedemptionCount;
}

class _PublisherBackendAwsSettings {
  const _PublisherBackendAwsSettings({
    required this.environmentName,
    required this.miniProgramId,
    required this.backendRootPath,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.samS3Bucket,
    required this.accessPolicyBucketName,
    required this.accessPolicyObjectKey,
    required this.requireAccessKeys,
    this.awsProfile,
  });

  final String environmentName;
  final String miniProgramId;
  final String backendRootPath;
  final String stackName;
  final String stageName;
  final String region;
  final String samS3Bucket;
  final String accessPolicyBucketName;
  final String accessPolicyObjectKey;
  final bool requireAccessKeys;
  final String? awsProfile;

  static _PublisherBackendAwsSettings fromEnvironment({
    required CloudEnvironmentConfiguration environment,
    required String miniProgramRootPath,
    String? stackNameOverride,
    String? stageNameOverride,
    String? samS3BucketOverride,
  }) {
    if (environment.provider != 'aws') {
      throw PublisherBackendException(
        'Cloud environment "${environment.name}" is not an aws environment.',
      );
    }

    String requiredValue(String key) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw PublisherBackendException(
          'Cloud environment "${environment.name}" is missing required aws '
          'setting "$key". Run `miniprogram env configure ${environment.name} '
          '--provider aws ...` again.',
        );
      }
      return value;
    }

    String optionalValue(String? explicit, String key, String fallback) {
      if (explicit != null && explicit.trim().isNotEmpty) {
        return explicit.trim();
      }
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    bool optionalBool(String key, bool fallback) {
      final rawValue = environment.values[key];
      if (rawValue == null) {
        return fallback;
      }
      final normalized = rawValue.toString().trim().toLowerCase();
      if (const <String>['true', '1', 'yes', 'y', 'on'].contains(normalized)) {
        return true;
      }
      if (const <String>['false', '0', 'no', 'n', 'off'].contains(normalized)) {
        return false;
      }
      throw PublisherBackendException(
        'Cloud environment "${environment.name}" has a non-boolean aws '
        'setting "$key".',
      );
    }

    final appId = _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
    final region = requiredValue('region');
    final bucket = requiredValue('bucket');
    final metadataPrefix = optionalValue(
      null,
      'metadataPrefix',
      'metadata',
    ).replaceAll(RegExp(r'^/+|/+$'), '');
    if (metadataPrefix.isEmpty) {
      throw PublisherBackendException(
        'Cloud environment "${environment.name}" has an empty aws setting '
        '"metadataPrefix".',
      );
    }
    if (metadataPrefix.contains('*') || metadataPrefix.contains('?')) {
      throw PublisherBackendException(
        'Cloud environment "${environment.name}" has unsafe wildcard '
        'characters in aws setting "metadataPrefix".',
      );
    }
    final stageName = optionalValue(stageNameOverride, 'stageName', 'prod');
    final samS3Bucket = optionalValue(
      samS3BucketOverride,
      'samS3Bucket',
      bucket,
    );
    final stackName = stackNameOverride?.trim().isNotEmpty == true
        ? stackNameOverride!.trim()
        : _defaultAwsPublisherBackendStackName(appId, environment.name);
    final awsProfile =
        environment.values['awsProfile']?.toString().trim().isEmpty == true
        ? null
        : environment.values['awsProfile']?.toString().trim();

    return _PublisherBackendAwsSettings(
      environmentName: environment.name,
      miniProgramId: appId,
      backendRootPath: p.join(miniProgramRootPath, 'backend', 'aws_lambda'),
      stackName: stackName,
      stageName: stageName,
      region: region,
      samS3Bucket: samS3Bucket,
      accessPolicyBucketName: bucket,
      accessPolicyObjectKey: '$metadataPrefix/access_keys/$appId.json',
      requireAccessKeys: optionalBool('requireAccessKeys', false),
      awsProfile: awsProfile,
    );
  }
}

class _PublisherBackendFirebaseSettings {
  const _PublisherBackendFirebaseSettings({
    required this.environmentName,
    required this.miniProgramId,
    required this.backendRootPath,
    required this.functionsRootPath,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.functionUrl,
    this.authWebApiKey,
  });

  final String environmentName;
  final String miniProgramId;
  final String backendRootPath;
  final String functionsRootPath;
  final String projectId;
  final String region;
  final String functionName;
  final String functionUrl;
  final String? authWebApiKey;

  String get healthUrl => _firebaseHealthUrlFromFunctionUrl(functionUrl);

  Map<String, String> get outputs => <String, String>{
    'PublisherBackendBaseUrl': functionUrl,
    'PublisherBackendHealthUrl': healthUrl,
    'PublisherBackendFunctionName': functionName,
    'PublisherBackendProjectId': projectId,
    'PublisherBackendRegion': region,
    'PublisherBackendStorageMode': _publisherBackendStorageFirestore,
    if (authWebApiKey?.trim().isNotEmpty == true)
      'PublisherBackendFirebaseAuthEmail': 'configured',
  };

  static _PublisherBackendFirebaseSettings fromEnvironment({
    required CloudEnvironmentConfiguration environment,
    required String miniProgramRootPath,
  }) {
    if (environment.provider != 'firebase') {
      throw PublisherBackendException(
        'Cloud environment "${environment.name}" is not a firebase environment.',
      );
    }

    String requiredValue(String key) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw PublisherBackendException(
          'Cloud environment "${environment.name}" is missing required '
          'firebase setting "$key". Run `miniprogram env configure '
          '${environment.name} --provider firebase ...` again.',
        );
      }
      return value;
    }

    String optionalValue(String key, String fallback) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    final appId = _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
    final projectId = requiredValue('projectId');
    final region = optionalValue('region', 'us-central1');
    final functionName = optionalValue('functionName', 'publisherBackend');
    final configuredFunctionUrl =
        environment.values['functionUrl']?.toString().trim() ?? '';
    final authWebApiKey =
        environment.values['authWebApiKey']?.toString().trim() ?? '';
    final functionUrl = configuredFunctionUrl.isEmpty
        ? _defaultFirebaseFunctionUrl(
            projectId: projectId,
            region: region,
            functionName: functionName,
          )
        : _normalizeFirebaseFunctionUrl(configuredFunctionUrl);
    final backendRootPath = p.join(
      miniProgramRootPath,
      'backend',
      'firebase_functions',
    );

    return _PublisherBackendFirebaseSettings(
      environmentName: environment.name,
      miniProgramId: appId,
      backendRootPath: backendRootPath,
      functionsRootPath: p.join(backendRootPath, 'functions'),
      projectId: projectId,
      region: region,
      functionName: functionName,
      functionUrl: functionUrl,
      authWebApiKey: authWebApiKey.isEmpty ? null : authWebApiKey,
    );
  }
}

String _defaultFirebaseFunctionUrl({
  required String projectId,
  required String region,
  required String functionName,
}) {
  return _normalizeFirebaseFunctionUrl(
    'https://$region-$projectId.cloudfunctions.net/$functionName',
  );
}

String _normalizeFirebaseFunctionUrl(String rawUrl) {
  final uri = Uri.parse(rawUrl.trim());
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw PublisherBackendException(
      'Firebase function URL must be an absolute HTTPS URL: $rawUrl',
    );
  }
  if (uri.scheme != 'https') {
    throw PublisherBackendException(
      'Firebase function URL must use https: $rawUrl',
    );
  }
  final withoutTrailingSlash = uri.toString().replaceFirst(RegExp(r'/+$'), '');
  return '$withoutTrailingSlash/';
}

String _firebaseHealthUrlFromFunctionUrl(String functionUrl) {
  final base = Uri.parse(_normalizeFirebaseFunctionUrl(functionUrl));
  return base.resolve('health').toString();
}
