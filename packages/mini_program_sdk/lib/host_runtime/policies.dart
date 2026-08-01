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

  MiniProgramFilePolicy _filePolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramFilePolicyProvider) {
      return (source as MiniProgramFilePolicyProvider).filePolicyFor(appId);
    }
    return const MiniProgramFilePolicy();
  }

  MiniProgramCameraPolicy _cameraPolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramCameraPolicyProvider) {
      return (source as MiniProgramCameraPolicyProvider).cameraPolicyFor(appId);
    }
    return const MiniProgramCameraPolicy();
  }

  MiniProgramFlashlightPolicy _flashlightPolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramFlashlightPolicyProvider) {
      return (source as MiniProgramFlashlightPolicyProvider)
          .flashlightPolicyFor(appId);
    }
    return const MiniProgramFlashlightPolicy();
  }
}
