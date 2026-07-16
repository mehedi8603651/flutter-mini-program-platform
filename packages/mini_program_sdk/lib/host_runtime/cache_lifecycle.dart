part of '../mini_program_host.dart';

extension _MiniProgramHostCacheLifecycle on _MiniProgramHostState {
  void _closeActiveCacheApp() {
    final appId = _activeCacheAppId;
    if (appId == null) {
      return;
    }
    unawaited(_cacheManager.closeApp(appId, policy: _activeCachePolicy));
    _activeCacheAppId = null;
    _activeCachePolicy = null;
  }
}
