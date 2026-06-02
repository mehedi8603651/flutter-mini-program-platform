part of '../mini_program_cloud_controller.dart';

class AwsCloudStackSettings {
  const AwsCloudStackSettings({
    required this.bucketName,
    required this.region,
    required this.artifactsPrefix,
    required this.metadataPrefix,
    required this.stackName,
    required this.stageName,
    required this.samS3Bucket,
    required this.functionTimeoutSeconds,
    required this.functionMemorySize,
    required this.logLevel,
    required this.requireAccessKeys,
    this.cloudFrontBaseUrl,
    this.apiBaseUrl,
    this.awsProfile,
  });

  final String bucketName;
  final String region;
  final String artifactsPrefix;
  final String metadataPrefix;
  final String stackName;
  final String stageName;
  final String samS3Bucket;
  final int functionTimeoutSeconds;
  final int functionMemorySize;
  final String logLevel;
  final bool requireAccessKeys;
  final String? cloudFrontBaseUrl;
  final String? apiBaseUrl;
  final String? awsProfile;

  factory AwsCloudStackSettings.fromEnvironment(
    CloudEnvironmentConfiguration environment,
  ) {
    if (environment.provider != 'aws') {
      throw MiniProgramCloudException(
        'Cloud environment "${environment.name}" is not an aws environment.',
      );
    }

    String requiredValue(String key) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw MiniProgramCloudException(
          'Cloud environment "${environment.name}" is missing required aws '
          'setting "$key". Run `miniprogram env configure ${environment.name} '
          '--provider aws ...` again.',
        );
      }
      return value;
    }

    String optionalValue(String key, String fallback) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    int optionalInt(String key, int fallback) {
      final rawValue = environment.values[key];
      if (rawValue == null) {
        return fallback;
      }
      final parsed = int.tryParse(rawValue.toString().trim());
      if (parsed == null) {
        throw MiniProgramCloudException(
          'Cloud environment "${environment.name}" has a non-integer aws '
          'setting "$key".',
        );
      }
      return parsed;
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
      throw MiniProgramCloudException(
        'Cloud environment "${environment.name}" has a non-boolean aws '
        'setting "$key".',
      );
    }

    final stackName = optionalValue(
      'stackName',
      _defaultStackName(environment.name),
    );
    final stageName = optionalValue('stageName', 'prod');
    final samS3Bucket = optionalValue('samS3Bucket', requiredValue('bucket'));
    final logLevel = optionalValue('logLevel', 'INFO').toUpperCase();
    if (!const <String>['DEBUG', 'INFO', 'WARN', 'ERROR'].contains(logLevel)) {
      throw MiniProgramCloudException(
        'Cloud environment "${environment.name}" has an unsupported aws '
        'logLevel "$logLevel".',
      );
    }

    return AwsCloudStackSettings(
      bucketName: requiredValue('bucket'),
      region: requiredValue('region'),
      artifactsPrefix: requiredValue('artifactsPrefix'),
      metadataPrefix: requiredValue('metadataPrefix'),
      stackName: stackName,
      stageName: stageName,
      samS3Bucket: samS3Bucket,
      functionTimeoutSeconds: optionalInt('functionTimeoutSeconds', 15),
      functionMemorySize: optionalInt('functionMemorySize', 256),
      logLevel: logLevel,
      requireAccessKeys: optionalBool('requireAccessKeys', false),
      cloudFrontBaseUrl: environment.values['cloudFrontBaseUrl']?.toString(),
      apiBaseUrl: environment.values['apiBaseUrl']?.toString(),
      awsProfile:
          environment.values['awsProfile']?.toString().trim().isEmpty == true
          ? null
          : environment.values['awsProfile']?.toString().trim(),
    );
  }
}

class _HealthProbeResult {
  const _HealthProbeResult({this.healthy, this.statusCode, this.error});

  final bool? healthy;
  final int? statusCode;
  final String? error;
}

String _defaultStackName(String environmentName) {
  final normalized = environmentName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = normalized.isEmpty ? 'default' : normalized;
  return 'mini-program-cloud-$suffix';
}

String _objectJoin(
  String first,
  String second, [
  String? third,
  String? fourth,
  String? fifth,
]) => <String?>[first, second, third, fourth, fifth]
    .where((value) => value != null)
    .cast<String>()
    .map((value) => value.replaceAll('\\', '/').trim())
    .where((value) => value.isNotEmpty)
    .map((value) => value.replaceAll(RegExp(r'^/+|/+$'), ''))
    .where((value) => value.isNotEmpty)
    .join('/');
