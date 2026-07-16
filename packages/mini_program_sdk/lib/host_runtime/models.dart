part of '../mini_program_host.dart';

class _RenderedMiniProgramScreen {
  _RenderedMiniProgramScreen.content({
    required this.screenId,
    required this.screenJson,
    this.routeParams = const <String, dynamic>{},
    this.usedStaleCache = false,
    this.cachedAssetCount = 0,
    this.downloadedAssetCount = 0,
    this.failedAssetCount = 0,
    Object? navigationIdentity,
  }) : navigationIdentity = navigationIdentity ?? Object(),
       failure = null;

  _RenderedMiniProgramScreen.failure({
    required this.screenId,
    required this.failure,
    this.routeParams = const <String, dynamic>{},
    Object? navigationIdentity,
  }) : screenJson = null,
       navigationIdentity = navigationIdentity ?? Object(),
       usedStaleCache = false,
       cachedAssetCount = 0,
       downloadedAssetCount = 0,
       failedAssetCount = 0;

  final String screenId;
  final Map<String, dynamic>? screenJson;
  final Map<String, dynamic> routeParams;
  final Object navigationIdentity;
  final MiniProgramFailure? failure;
  final bool usedStaleCache;
  final int cachedAssetCount;
  final int downloadedAssetCount;
  final int failedAssetCount;

  int get resolvedAssetCount => cachedAssetCount + downloadedAssetCount;

  _RenderedMiniProgramScreen withRouteResult(Map<String, dynamic> result) {
    final updatedParams = <String, dynamic>{...routeParams}..remove('result');
    if (result.isNotEmpty) {
      updatedParams['result'] = result;
    }
    if (failure != null) {
      return _RenderedMiniProgramScreen.failure(
        screenId: screenId,
        failure: failure!,
        routeParams: updatedParams,
        navigationIdentity: navigationIdentity,
      );
    }
    return _RenderedMiniProgramScreen.content(
      screenId: screenId,
      screenJson: screenJson!,
      routeParams: updatedParams,
      usedStaleCache: usedStaleCache,
      cachedAssetCount: cachedAssetCount,
      downloadedAssetCount: downloadedAssetCount,
      failedAssetCount: failedAssetCount,
      navigationIdentity: navigationIdentity,
    );
  }
}
