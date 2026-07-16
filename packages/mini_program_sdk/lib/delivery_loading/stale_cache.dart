part of '../manifest_loader.dart';

extension _StaleDeliveryCacheRules on ManifestLoader {
  bool _canUseStaleCache(MiniProgramSourceException? sourceException) {
    final errorCode = sourceException?.errorCode;
    return errorCode == MiniProgramErrorCodes.backendUnreachable ||
        errorCode == MiniProgramErrorCodes.backendTimeout;
  }

  bool _isWithinMaxStaleAge({
    required DateTime cachedAt,
    required Duration maxStaleAge,
  }) {
    return DateTime.now().difference(cachedAt) <= maxStaleAge;
  }
}
