part of '../mini_program_data_resource.dart';

Future<MiniProgramDataResourceLoadResult> _loadDataResource(
  MiniProgramDataResourceManager manager, {
  required String appId,
  required String version,
  required String resourceId,
  required String assetPath,
  required Duration ttl,
  required bool forceRefresh,
  required MiniProgramJsonAssetSource? source,
  required MiniProgramCacheManager cacheManager,
  required MiniProgramCachePolicy cachePolicy,
}) async {
  _validateResourceId(resourceId);
  _validateJsonAssetPath(assetPath);
  _ensureDataCacheEnabled(cachePolicy);
  final resourceKey = _resourceKey(appId, version, resourceId);
  final cacheKey = _cacheKey(version, resourceId);
  final appCache = cacheManager.forApp(appId, policy: cachePolicy);

  if (!forceRefresh) {
    final cached = await appCache.get<Object?>(
      cacheKey,
      bucket: MiniProgramCacheBucket.data,
    );
    if (cached != null) {
      final encoded = utf8.encode(jsonEncode(cached));
      _validateJsonValue(cached, encoded.length, cachePolicy);
      _replaceDataResource(
        manager,
        resourceKey,
        _LoadedDataResource(assetPath: assetPath, value: cached),
      );
      return MiniProgramDataResourceLoadResult(
        id: resourceId,
        asset: assetPath,
        fromCache: true,
        bytes: encoded.length,
      );
    }
  }

  if (source == null) {
    throw const MiniProgramDataException(
      code: MiniProgramErrorCodes.dataAssetUnavailable,
      message: 'The active mini-program source cannot load JSON assets.',
    );
  }

  late final List<int> bytes;
  try {
    bytes = await source.loadJsonAsset(
      miniProgramId: appId,
      version: version,
      assetPath: assetPath,
    );
  } on MiniProgramSourceException catch (error) {
    if (error.statusCode == 404) {
      throw MiniProgramDataException(
        code: MiniProgramErrorCodes.dataResourceNotFound,
        message: 'JSON data asset "$assetPath" was not found.',
        details: <String, dynamic>{'asset': assetPath},
      );
    }
    if (error.errorCode == MiniProgramErrorCodes.dataAssetUnavailable) {
      throw MiniProgramDataException(
        code: MiniProgramErrorCodes.dataAssetUnavailable,
        message: error.message,
        details: error.details,
      );
    }
    rethrow;
  }
  if (bytes.length > _effectiveMaxBytes(cachePolicy)) {
    throw MiniProgramDataException(
      code: MiniProgramErrorCodes.dataResourceTooLarge,
      message: 'JSON data asset exceeds the accepted size limit.',
      details: <String, dynamic>{
        'asset': assetPath,
        'actualBytes': bytes.length,
        'maxBytes': _effectiveMaxBytes(cachePolicy),
      },
    );
  }

  late final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } catch (_) {
    throw MiniProgramDataException(
      code: MiniProgramErrorCodes.dataInvalidJson,
      message: 'JSON data asset "$assetPath" is malformed.',
      details: <String, dynamic>{'asset': assetPath},
    );
  }
  _validateJsonValue(decoded, bytes.length, cachePolicy);
  await appCache.set(
    cacheKey,
    decoded,
    bucket: MiniProgramCacheBucket.data,
    ttl: ttl,
    priority: MiniProgramCachePriority.normal,
  );
  _replaceDataResource(
    manager,
    resourceKey,
    _LoadedDataResource(assetPath: assetPath, value: decoded),
  );
  return MiniProgramDataResourceLoadResult(
    id: resourceId,
    asset: assetPath,
    fromCache: false,
    bytes: bytes.length,
  );
}
