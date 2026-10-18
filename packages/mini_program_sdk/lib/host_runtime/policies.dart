part of '../mini_program_host.dart';

extension _MiniProgramHostPolicies on _MiniProgramHostState {
  MiniProgramPhonePolicy _phonePolicyFor(String appId) {
    final source = widget.source;
    return source is MiniProgramPhonePolicyProvider
        ? (source as MiniProgramPhonePolicyProvider).phonePolicyFor(appId)
        : const MiniProgramPhonePolicy();
  }

  MiniProgramVibrationPolicy _vibrationPolicyFor(String appId) {
    final source = widget.source;
    return source is MiniProgramVibrationPolicyProvider
        ? (source as MiniProgramVibrationPolicyProvider).vibrationPolicyFor(
            appId,
          )
        : const MiniProgramVibrationPolicy();
  }

  MiniProgramClipboardPolicy _clipboardPolicyFor(String appId) {
    final source = widget.source;
    return source is MiniProgramClipboardPolicyProvider
        ? (source as MiniProgramClipboardPolicyProvider).clipboardPolicyFor(
            appId,
          )
        : const MiniProgramClipboardPolicy();
  }

  MiniProgramGalleryPolicy _galleryPolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramGalleryPolicyProvider) {
      return (source as MiniProgramGalleryPolicyProvider).galleryPolicyFor(
        appId,
      );
    }
    return const MiniProgramGalleryPolicy();
  }

  MiniProgramMicrophonePolicy _microphonePolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramMicrophonePolicyProvider) {
      return (source as MiniProgramMicrophonePolicyProvider)
          .microphonePolicyFor(appId);
    }
    return const MiniProgramMicrophonePolicy();
  }

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

  MiniProgramDisplayBrightnessPolicy _displayBrightnessPolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramDisplayBrightnessPolicyProvider) {
      return (source as MiniProgramDisplayBrightnessPolicyProvider)
          .displayBrightnessPolicyFor(appId);
    }
    return const MiniProgramDisplayBrightnessPolicy();
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

  MiniProgramQrPolicy _qrPolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramQrPolicyProvider) {
      return (source as MiniProgramQrPolicyProvider).qrPolicyFor(appId);
    }
    return const MiniProgramQrPolicy();
  }

  MiniProgramSharePolicy _sharePolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramSharePolicyProvider) {
      return (source as MiniProgramSharePolicyProvider).sharePolicyFor(appId);
    }
    return const MiniProgramSharePolicy();
  }

  MiniProgramMediaPlaybackPolicy _mediaPlaybackPolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramMediaPlaybackPolicyProvider) {
      return (source as MiniProgramMediaPlaybackPolicyProvider)
          .mediaPlaybackPolicyFor(appId);
    }
    return const MiniProgramMediaPlaybackPolicy();
  }
}
