import 'aws_cloud_publisher.dart';
import 'local_cli_state.dart';
import 'mini_program_builder.dart';
import 'mini_program_publisher.dart';

class MiniProgramCloudPublishRequest {
  const MiniProgramCloudPublishRequest({
    required this.repoRootPath,
    required this.environment,
    this.miniProgramId,
    this.miniProgramRootPath,
    this.stacCliScriptPath,
    this.skipBuildPubGet = false,
  });

  final String repoRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? miniProgramId;
  final String? miniProgramRootPath;
  final String? stacCliScriptPath;
  final bool skipBuildPubGet;
}

class CloudPublishedObjectRecord {
  const CloudPublishedObjectRecord({
    required this.key,
    required this.localSourcePath,
    required this.contentType,
    required this.cacheControl,
    this.versionId,
  });

  final String key;
  final String localSourcePath;
  final String? contentType;
  final String cacheControl;
  final String? versionId;
}

class MiniProgramCloudPublishResult {
  const MiniProgramCloudPublishResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.version,
    required this.buildResult,
    required this.bucketName,
    required this.region,
    required this.artifactRootKey,
    required this.manifestKey,
    required this.screensPrefixKey,
    required this.metadataReleaseKey,
    required this.metadataCatalogKey,
    required this.publishedAtUtc,
    required this.uploadedObjects,
    this.assetsPrefixKey,
    this.cloudFrontBaseUrl,
    this.apiBaseUrl,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String version;
  final MiniProgramBuildResult buildResult;
  final String bucketName;
  final String region;
  final String artifactRootKey;
  final String manifestKey;
  final String screensPrefixKey;
  final String? assetsPrefixKey;
  final String metadataReleaseKey;
  final String metadataCatalogKey;
  final String publishedAtUtc;
  final List<CloudPublishedObjectRecord> uploadedObjects;
  final String? cloudFrontBaseUrl;
  final String? apiBaseUrl;
}

class MiniProgramCloudPublisher {
  const MiniProgramCloudPublisher({
    AwsCloudPublisher awsPublisher = const AwsCloudPublisher(),
  }) : _awsPublisher = awsPublisher;

  final AwsCloudPublisher _awsPublisher;

  Future<MiniProgramCloudPublishResult> publish(
    MiniProgramCloudPublishRequest request,
  ) async {
    switch (request.environment.provider) {
      case 'aws':
        return _awsPublisher.publish(request);
      case 'gcp':
      case 'custom-s3-compatible':
        throw MiniProgramPublishException(
          'Cloud provider "${request.environment.provider}" is not '
          'implemented yet. This phase currently supports aws only.',
        );
    }

    throw MiniProgramPublishException(
      'Unsupported cloud provider: ${request.environment.provider}',
    );
  }
}
