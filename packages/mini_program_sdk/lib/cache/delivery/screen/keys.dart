String buildScreenCacheKey({
  required String miniProgramId,
  required String version,
  required String screenId,
}) => '$miniProgramId::$version::$screenId';
