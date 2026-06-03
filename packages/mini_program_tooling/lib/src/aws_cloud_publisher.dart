import 'dart:convert';
import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'local_cli_state.dart';
import 'mini_program_builder.dart';
import 'mini_program_cloud_publisher.dart';
import 'mini_program_publisher.dart';

typedef AwsProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

Future<ProcessResult> _defaultAwsProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: false,
  );
}

class AwsCloudEnvironmentSettings {
  const AwsCloudEnvironmentSettings({
    required this.bucketName,
    required this.region,
    required this.artifactsPrefix,
    required this.metadataPrefix,
    this.cloudFrontBaseUrl,
    this.apiBaseUrl,
    this.awsProfile,
  });

  final String bucketName;
  final String region;
  final String artifactsPrefix;
  final String metadataPrefix;
  final String? cloudFrontBaseUrl;
  final String? apiBaseUrl;
  final String? awsProfile;

  factory AwsCloudEnvironmentSettings.fromEnvironment(
    CloudEnvironmentConfiguration environment,
  ) {
    if (environment.provider != 'aws') {
      throw MiniProgramPublishException(
        'Cloud environment "${environment.name}" is not an aws environment.',
      );
    }

    String requiredValue(String key) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw MiniProgramPublishException(
          'Cloud environment "${environment.name}" is missing required aws '
          'setting "$key". Run `miniprogram env configure ${environment.name} '
          '--provider aws ...` again.',
        );
      }
      return value;
    }

    String? optionalValue(String key) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }

    return AwsCloudEnvironmentSettings(
      bucketName: requiredValue('bucket'),
      region: requiredValue('region'),
      artifactsPrefix: _normalizeObjectPrefix(
        environment.values['artifactsPrefix']?.toString() ?? 'artifacts',
      ),
      metadataPrefix: _normalizeObjectPrefix(
        environment.values['metadataPrefix']?.toString() ?? 'metadata',
      ),
      cloudFrontBaseUrl: _normalizeBaseUrl(optionalValue('cloudFrontBaseUrl')),
      apiBaseUrl: _normalizeBaseUrl(optionalValue('apiBaseUrl')),
      awsProfile: optionalValue('awsProfile'),
    );
  }
}

class AwsCloudPublisher {
  const AwsCloudPublisher({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
    AwsProcessRunner shellRunner = _defaultAwsProcessRunner,
  }) : _builder = builder,
       _shellRunner = shellRunner;

  final MiniProgramBuilder _builder;
  final AwsProcessRunner _shellRunner;

  Future<MiniProgramCloudPublishResult> publish(
    MiniProgramCloudPublishRequest request,
  ) async {
    final settings = AwsCloudEnvironmentSettings.fromEnvironment(
      request.environment,
    );
    final repoRootPath = p.normalize(p.absolute(request.repoRootPath));
    final buildResult = await _builder.build(
      MiniProgramBuildRequest(
        repoRootPath: repoRootPath,
        miniProgramId: request.miniProgramId,
        miniProgramRootPath: request.miniProgramRootPath,
        stacCliScriptPath: request.stacCliScriptPath,
        mpBuildScriptPath: request.mpBuildScriptPath,
        skipPubGet: request.skipBuildPubGet,
      ),
    );

    final manifestPath = p.join(
      buildResult.miniProgramRootPath,
      'manifest.json',
    );
    final manifestJson = await _readManifestJson(manifestPath);
    final manifest = _parseManifest(manifestJson, manifestPath);
    final version = manifest.version.trim();
    if (version.isEmpty) {
      throw MiniProgramPublishException(
        'Manifest is missing a usable version: $manifestPath',
      );
    }
    _validateSemanticVersion(version, manifestPath);

    await _assertBucketVersioningEnabled(settings);

    final publishedAtUtc = DateTime.now().toUtc().toIso8601String();
    final artifactRootKey = _objectJoin(
      settings.artifactsPrefix,
      buildResult.miniProgramId,
      version,
    );
    final manifestKey = _objectJoin(artifactRootKey, 'manifest.json');
    final screensPrefixKey = _objectJoin(artifactRootKey, 'screens');
    final assetsDirectory = Directory(
      p.join(buildResult.miniProgramRootPath, 'assets'),
    );
    final assetsPrefixKey = await assetsDirectory.exists()
        ? _objectJoin(artifactRootKey, 'assets')
        : null;
    final metadataReleaseKey = _objectJoin(
      settings.metadataPrefix,
      'releases',
      buildResult.miniProgramId,
      '$version.json',
    );
    final metadataCatalogKey = _objectJoin(
      settings.metadataPrefix,
      'catalog',
      '${buildResult.miniProgramId}.json',
    );

    final tempDirectory = await Directory.systemTemp.createTemp(
      'mini_program_cloud_publish_',
    );
    try {
      final uploadPlans = <_AwsObjectUploadPlan>[
        _AwsObjectUploadPlan(
          key: manifestKey,
          localSourcePath: manifestPath,
          contentType: 'application/json',
          cacheControl: _immutableCacheControl,
        ),
      ];

      final screenFiles = await _listJsonFiles(
        buildResult.screensDirectoryPath,
      );
      if (screenFiles.isEmpty) {
        throw MiniProgramPublishException(
          'No built screen JSON files were found in '
          '${buildResult.screensDirectoryPath}',
        );
      }
      for (final screenFile in screenFiles) {
        uploadPlans.add(
          _AwsObjectUploadPlan(
            key: _objectJoin(screensPrefixKey, p.basename(screenFile.path)),
            localSourcePath: screenFile.path,
            contentType: 'application/json',
            cacheControl: _immutableCacheControl,
          ),
        );
      }

      if (assetsPrefixKey != null) {
        final assetFiles = await _listAllFiles(assetsDirectory.path);
        for (final assetFile in assetFiles) {
          final relativePath = p
              .relative(assetFile.path, from: assetsDirectory.path)
              .replaceAll('\\', '/');
          uploadPlans.add(
            _AwsObjectUploadPlan(
              key: _objectJoin(assetsPrefixKey, relativePath),
              localSourcePath: assetFile.path,
              contentType: _guessContentType(assetFile.path),
              cacheControl: _immutableCacheControl,
            ),
          );
        }
      }

      final releaseMetadataPath = p.join(
        tempDirectory.path,
        '${buildResult.miniProgramId}_$version.release.json',
      );
      final catalogMetadataPath = p.join(
        tempDirectory.path,
        '${buildResult.miniProgramId}.catalog.json',
      );
      await File(releaseMetadataPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          _buildReleaseMetadata(
            environmentName: request.environment.name,
            miniProgramId: buildResult.miniProgramId,
            version: version,
            publishedAtUtc: publishedAtUtc,
            settings: settings,
            artifactRootKey: artifactRootKey,
            manifestKey: manifestKey,
            screensPrefixKey: screensPrefixKey,
            assetsPrefixKey: assetsPrefixKey,
            screenFormat: buildResult.screenFormat,
            screenSchemaVersion: buildResult.screenSchemaVersion,
          ),
        ),
      );
      await File(catalogMetadataPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          _buildCatalogMetadata(
            environmentName: request.environment.name,
            miniProgramId: buildResult.miniProgramId,
            version: version,
            publishedAtUtc: publishedAtUtc,
            provider: request.environment.provider,
            metadataReleaseKey: metadataReleaseKey,
            screenFormat: buildResult.screenFormat,
            screenSchemaVersion: buildResult.screenSchemaVersion,
          ),
        ),
      );

      uploadPlans.addAll(<_AwsObjectUploadPlan>[
        _AwsObjectUploadPlan(
          key: metadataReleaseKey,
          localSourcePath: releaseMetadataPath,
          contentType: 'application/json',
          cacheControl: _immutableCacheControl,
        ),
        _AwsObjectUploadPlan(
          key: metadataCatalogKey,
          localSourcePath: catalogMetadataPath,
          contentType: 'application/json',
          cacheControl: _mutableMetadataCacheControl,
        ),
      ]);

      final uploadedObjects = <CloudPublishedObjectRecord>[];
      for (final plan in uploadPlans) {
        final versionId = await _putObject(settings, plan);
        uploadedObjects.add(
          CloudPublishedObjectRecord(
            key: plan.key,
            localSourcePath: plan.localSourcePath,
            contentType: plan.contentType,
            cacheControl: plan.cacheControl,
            versionId: versionId,
          ),
        );
      }

      return MiniProgramCloudPublishResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        miniProgramId: buildResult.miniProgramId,
        version: version,
        buildResult: buildResult,
        bucketName: settings.bucketName,
        region: settings.region,
        artifactRootKey: artifactRootKey,
        manifestKey: manifestKey,
        screensPrefixKey: screensPrefixKey,
        assetsPrefixKey: assetsPrefixKey,
        metadataReleaseKey: metadataReleaseKey,
        metadataCatalogKey: metadataCatalogKey,
        publishedAtUtc: publishedAtUtc,
        uploadedObjects: uploadedObjects,
        cloudFrontBaseUrl: settings.cloudFrontBaseUrl,
        apiBaseUrl: settings.apiBaseUrl,
      );
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _assertBucketVersioningEnabled(
    AwsCloudEnvironmentSettings settings,
  ) async {
    final response = await _runAwsJsonCommand(settings, <String>[
      's3api',
      'get-bucket-versioning',
      '--bucket',
      settings.bucketName,
      '--output',
      'json',
    ]);
    final status = response['Status']?.toString().trim();
    if (status != 'Enabled') {
      throw MiniProgramPublishException(
        'AWS bucket "${settings.bucketName}" in region "${settings.region}" '
        'does not have versioning enabled. Enable S3 bucket versioning before '
        'running cloud publish.',
      );
    }
  }

  Future<String?> _putObject(
    AwsCloudEnvironmentSettings settings,
    _AwsObjectUploadPlan plan,
  ) async {
    final arguments = <String>[
      's3api',
      'put-object',
      '--bucket',
      settings.bucketName,
      '--key',
      plan.key,
      '--body',
      plan.localSourcePath,
      '--cache-control',
      plan.cacheControl,
      '--output',
      'json',
    ];
    if (plan.contentType != null) {
      arguments.addAll(<String>['--content-type', plan.contentType!]);
    }

    final response = await _runAwsJsonCommand(settings, arguments);
    final versionId = response['VersionId']?.toString().trim();
    return versionId == null || versionId.isEmpty ? null : versionId;
  }

  Future<Map<String, dynamic>> _runAwsJsonCommand(
    AwsCloudEnvironmentSettings settings,
    List<String> commandArguments,
  ) async {
    final arguments = <String>[
      ..._buildAwsGlobalArguments(settings),
      ...commandArguments,
    ];

    ProcessResult result;
    try {
      result = await _shellRunner('aws', arguments);
    } on ProcessException catch (error) {
      throw MiniProgramPublishException(
        'Failed to launch the AWS CLI. Install `aws` and make sure it is on '
        'your PATH.\n$error',
      );
    }

    if (result.exitCode != 0) {
      final stdoutText = '${result.stdout}'.trim();
      final stderrText = '${result.stderr}'.trim();
      throw MiniProgramPublishException(
        'AWS CLI command failed.\n'
        'Command: aws ${arguments.join(' ')}\n'
        'stdout: ${stdoutText.isEmpty ? '(empty)' : stdoutText}\n'
        'stderr: ${stderrText.isEmpty ? '(empty)' : stderrText}',
      );
    }

    final stdoutText = '${result.stdout}'.trim();
    if (stdoutText.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map) {
      throw MiniProgramPublishException(
        'AWS CLI returned non-object JSON for command: aws '
        '${arguments.join(' ')}',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  List<String> _buildAwsGlobalArguments(AwsCloudEnvironmentSettings settings) {
    final arguments = <String>['--region', settings.region];
    if (settings.awsProfile case final profile?
        when profile.trim().isNotEmpty) {
      arguments.addAll(<String>['--profile', profile]);
    }
    return arguments;
  }

  Future<Map<String, dynamic>> _readManifestJson(String manifestPath) async {
    final file = File(manifestPath);
    if (!await file.exists()) {
      throw MiniProgramPublishException(
        'Manifest was not found: $manifestPath',
      );
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw MiniProgramPublishException(
        'Manifest is not a JSON object: $manifestPath',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  MiniProgramManifest _parseManifest(
    Map<String, dynamic> manifestJson,
    String manifestPath,
  ) {
    try {
      return MiniProgramManifest.fromJson(manifestJson);
    } catch (error) {
      throw MiniProgramPublishException(
        'Manifest could not be parsed: $manifestPath\n$error',
      );
    }
  }

  void _validateSemanticVersion(String value, String manifestPath) {
    try {
      Version.parse(value);
    } on FormatException {
      throw MiniProgramPublishException(
        'Manifest version "$value" is not a valid semantic version: '
        '$manifestPath',
      );
    }
  }

  Future<List<File>> _listJsonFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw MiniProgramPublishException(
        'Built screens directory does not exist: $directoryPath',
      );
    }

    final files = await directory
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<List<File>> _listAllFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return <File>[];
    }

    final files = await directory
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Map<String, dynamic> _buildReleaseMetadata({
    required String environmentName,
    required String miniProgramId,
    required String version,
    required String publishedAtUtc,
    required AwsCloudEnvironmentSettings settings,
    required String artifactRootKey,
    required String manifestKey,
    required String screensPrefixKey,
    required String? assetsPrefixKey,
    required String screenFormat,
    required int? screenSchemaVersion,
  }) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'provider': 'aws',
      'environment': environmentName,
      'miniProgramId': miniProgramId,
      'version': version,
      'screenFormat': screenFormat,
      if (screenSchemaVersion != null)
        'screenSchemaVersion': screenSchemaVersion,
      'publishedAtUtc': publishedAtUtc,
      'artifacts': <String, dynamic>{
        'bucket': settings.bucketName,
        'region': settings.region,
        'artifactRootKey': artifactRootKey,
        'manifestKey': manifestKey,
        'screensPrefixKey': screensPrefixKey,
        if (assetsPrefixKey != null) 'assetsPrefixKey': assetsPrefixKey,
        if (settings.cloudFrontBaseUrl != null)
          'manifestUrl': _resolvePublicUrl(
            settings.cloudFrontBaseUrl!,
            manifestKey,
          ),
        if (settings.cloudFrontBaseUrl != null)
          'screensBaseUrl': _resolvePublicUrl(
            settings.cloudFrontBaseUrl!,
            '$screensPrefixKey/',
          ),
        if (settings.cloudFrontBaseUrl != null && assetsPrefixKey != null)
          'assetsBaseUrl': _resolvePublicUrl(
            settings.cloudFrontBaseUrl!,
            '$assetsPrefixKey/',
          ),
      },
      if (settings.apiBaseUrl != null) 'apiBaseUrl': settings.apiBaseUrl,
    };
  }

  Map<String, dynamic> _buildCatalogMetadata({
    required String environmentName,
    required String miniProgramId,
    required String version,
    required String publishedAtUtc,
    required String provider,
    required String metadataReleaseKey,
    required String screenFormat,
    required int? screenSchemaVersion,
  }) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'provider': provider,
      'environment': environmentName,
      'miniProgramId': miniProgramId,
      'latestVersion': version,
      'screenFormat': screenFormat,
      if (screenSchemaVersion != null)
        'screenSchemaVersion': screenSchemaVersion,
      'updatedAtUtc': publishedAtUtc,
      'releaseKey': metadataReleaseKey,
    };
  }
}

class _AwsObjectUploadPlan {
  const _AwsObjectUploadPlan({
    required this.key,
    required this.localSourcePath,
    required this.cacheControl,
    this.contentType,
  });

  final String key;
  final String localSourcePath;
  final String? contentType;
  final String cacheControl;
}

const String _immutableCacheControl = 'public, max-age=31536000, immutable';
const String _mutableMetadataCacheControl =
    'no-cache, no-store, must-revalidate';

String _normalizeObjectPrefix(String value) {
  final normalized = value.replaceAll('\\', '/').trim();
  final trimmed = normalized.replaceAll(RegExp(r'^/+|/+$'), '');
  if (trimmed.isEmpty) {
    throw MiniProgramPublishException(
      'Cloud object prefixes must not be blank.',
    );
  }
  return trimmed;
}

String? _normalizeBaseUrl(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw MiniProgramPublishException(
      'Cloud base URL is not a valid absolute URL: $value',
    );
  }
  return trimmed.replaceFirst(RegExp(r'/+$'), '');
}

String _objectJoin(
  String first,
  String second, [
  String? third,
  String? fourth,
]) {
  final parts = <String>[first, second];
  if (third != null && third.isNotEmpty) {
    parts.add(third);
  }
  if (fourth != null && fourth.isNotEmpty) {
    parts.add(fourth);
  }
  return parts.join('/').replaceAll('//', '/');
}

String _resolvePublicUrl(String baseUrl, String objectKey) {
  final normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
  final normalizedObjectKey = objectKey.replaceAll('\\', '/');
  return Uri.parse(
    '$normalizedBaseUrl/',
  ).resolve(normalizedObjectKey).toString();
}

String? _guessContentType(String filePath) {
  switch (p.extension(filePath).toLowerCase()) {
    case '.css':
      return 'text/css';
    case '.gif':
      return 'image/gif';
    case '.html':
      return 'text/html';
    case '.jpeg':
    case '.jpg':
      return 'image/jpeg';
    case '.js':
      return 'application/javascript';
    case '.json':
      return 'application/json';
    case '.otf':
      return 'font/otf';
    case '.png':
      return 'image/png';
    case '.svg':
      return 'image/svg+xml';
    case '.ttf':
      return 'font/ttf';
    case '.txt':
      return 'text/plain';
    case '.webp':
      return 'image/webp';
    case '.woff':
      return 'font/woff';
    case '.woff2':
      return 'font/woff2';
  }
  return null;
}
