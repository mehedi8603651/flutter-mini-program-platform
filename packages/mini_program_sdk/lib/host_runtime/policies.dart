part of '../mini_program_host.dart';

extension _MiniProgramHostPolicies on _MiniProgramHostState {
  MiniProgramCachePolicy _cachePolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramCachePolicyProvider) {
      return (source as MiniProgramCachePolicyProvider).cachePolicyFor(appId);
    }
    return _cacheManager.defaultPolicy;
  }

  MiniProgramLiveStatePolicy _liveStatePolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramLiveStatePolicyProvider) {
      return (source as MiniProgramLiveStatePolicyProvider).liveStatePolicyFor(
        appId,
      );
    }
    return const MiniProgramLiveStatePolicy();
  }

  MiniProgramLocationPolicy _locationPolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramLocationPolicyProvider) {
      return (source as MiniProgramLocationPolicyProvider).locationPolicyFor(
        appId,
      );
    }
    return const MiniProgramLocationPolicy();
  }
}
