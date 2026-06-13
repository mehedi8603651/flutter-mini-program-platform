import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'cache/manifest_cache.dart';
import 'cache/screen_cache.dart';
import 'network/mini_program_source.dart';
import 'network/mini_program_source_exception.dart';

/// Delivery-source shape used by host discovery lists before opening a flow.
enum MiniProgramDiscoverySourceKind {
  /// Mini-program content is bundled with the host app.
  bundled,

  /// Mini-program content is fetched from a remote artifact service.
  remote,
}

/// User-facing availability state for a mini-program card in host discovery UI.
enum MiniProgramDiscoveryStatus {
  /// The backend is reachable and the current release can be opened normally.
  live,

  /// The release is available from a bundled or local copy.
  cached,

  /// The backend is unavailable, but a valid cached copy may still be opened.
  staleButAllowed,

  /// No current or valid offline copy is available to open.
  unavailable,
}

/// Resolved discovery state for one mini-program in a host list.
@immutable
class MiniProgramDiscoveryState {
  const MiniProgramDiscoveryState({
    required this.miniProgramId,
    required this.status,
    this.manifest,
    this.message,
    this.errorCode,
    this.manifestCachedAt,
    this.entryScreenCachedAt,
    this.details = const <String, dynamic>{},
  });

  final String miniProgramId;
  final MiniProgramDiscoveryStatus status;
  final MiniProgramManifest? manifest;
  final String? message;
  final String? errorCode;
  final DateTime? manifestCachedAt;
  final DateTime? entryScreenCachedAt;
  final Map<String, dynamic> details;

  bool get canOpen => status != MiniProgramDiscoveryStatus.unavailable;

  String get badgeLabel => switch (status) {
    MiniProgramDiscoveryStatus.live => 'Live',
    MiniProgramDiscoveryStatus.cached => 'Cached',
    MiniProgramDiscoveryStatus.staleButAllowed => 'Offline',
    MiniProgramDiscoveryStatus.unavailable => 'Unavailable',
  };

  String get displayMessage =>
      message ??
      switch (status) {
        MiniProgramDiscoveryStatus.live =>
          'Latest release is available from the artifact endpoint.',
        MiniProgramDiscoveryStatus.cached =>
          'Bundled release is available without remote artifact delivery.',
        MiniProgramDiscoveryStatus.staleButAllowed =>
          'Cached release available while the artifact endpoint is offline.',
        MiniProgramDiscoveryStatus.unavailable =>
          'No valid offline copy is available.',
      };
}

/// Resolves list-level availability without fully opening the mini-program UI.
class MiniProgramDiscoveryResolver {
  const MiniProgramDiscoveryResolver({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  Future<MiniProgramDiscoveryState> resolve({
    required String miniProgramId,
    required MiniProgramSource source,
    required ManifestCache manifestCache,
    required ScreenCache screenCache,
    required MiniProgramDiscoverySourceKind sourceKind,
  }) async {
    final cachedManifest = await manifestCache.read(miniProgramId);

    try {
      final manifest = await source.loadManifest(miniProgramId);
      if (sourceKind == MiniProgramDiscoverySourceKind.remote) {
        await _updateManifestCache(
          miniProgramId: miniProgramId,
          manifest: manifest,
          manifestCache: manifestCache,
        );
      }

      return MiniProgramDiscoveryState(
        miniProgramId: miniProgramId,
        status: switch (sourceKind) {
          MiniProgramDiscoverySourceKind.bundled =>
            MiniProgramDiscoveryStatus.cached,
          MiniProgramDiscoverySourceKind.remote =>
            MiniProgramDiscoveryStatus.live,
        },
        manifest: manifest,
      );
    } catch (error) {
      final sourceException = error is MiniProgramSourceException
          ? error
          : null;

      if (sourceKind == MiniProgramDiscoverySourceKind.remote &&
          cachedManifest != null &&
          cachedManifest.manifest.allowsManifestStaleCache &&
          _isWithinMaxStaleAge(
            cachedAt: cachedManifest.cachedAt,
            maxStaleAge: cachedManifest.manifest.manifestMaxStaleAge,
          ) &&
          _canUseOfflineCache(sourceException)) {
        final cachedEntryScreen = await screenCache.read(
          miniProgramId: miniProgramId,
          version: cachedManifest.manifest.version,
          screenId: cachedManifest.manifest.entry,
        );

        if (cachedEntryScreen != null &&
            cachedManifest.manifest.allowsEntryScreenStaleCache &&
            _isWithinMaxStaleAge(
              cachedAt: cachedEntryScreen.cachedAt,
              maxStaleAge: cachedManifest.manifest.entryScreenMaxStaleAge,
            )) {
          return MiniProgramDiscoveryState(
            miniProgramId: miniProgramId,
            status: MiniProgramDiscoveryStatus.staleButAllowed,
            manifest: cachedManifest.manifest,
            errorCode: sourceException?.errorCode,
            manifestCachedAt: cachedManifest.cachedAt,
            entryScreenCachedAt: cachedEntryScreen.cachedAt,
            details: <String, dynamic>{
              'offlineFallback': true,
              if (sourceException != null) ...sourceException.details,
            },
          );
        }
      }

      return MiniProgramDiscoveryState(
        miniProgramId: miniProgramId,
        status: MiniProgramDiscoveryStatus.unavailable,
        manifest: cachedManifest?.manifest,
        errorCode: sourceException?.errorCode,
        manifestCachedAt: cachedManifest?.cachedAt,
        message: _unavailableMessage(sourceKind, sourceException),
        details: <String, dynamic>{
          if (cachedManifest != null) ...<String, dynamic>{
            'manifestCacheExpired': !_isWithinMaxStaleAge(
              cachedAt: cachedManifest.cachedAt,
              maxStaleAge: cachedManifest.manifest.manifestMaxStaleAge,
            ),
          },
          if (sourceException != null) ...sourceException.details,
        },
      );
    }
  }

  Future<void> _updateManifestCache({
    required String miniProgramId,
    required MiniProgramManifest manifest,
    required ManifestCache manifestCache,
  }) async {
    if (manifest.allowsManifestStaleCache) {
      await manifestCache.write(
        CachedManifestEntry(
          miniProgramId: miniProgramId,
          manifest: manifest,
          cachedAt: _now(),
        ),
      );
      return;
    }

    await manifestCache.remove(miniProgramId);
  }

  bool _canUseOfflineCache(MiniProgramSourceException? sourceException) {
    final errorCode = sourceException?.errorCode;
    return errorCode == MiniProgramErrorCodes.backendUnreachable ||
        errorCode == MiniProgramErrorCodes.backendTimeout;
  }

  bool _isWithinMaxStaleAge({
    required DateTime cachedAt,
    required Duration maxStaleAge,
  }) {
    return _now().difference(cachedAt) <= maxStaleAge;
  }

  String _unavailableMessage(
    MiniProgramDiscoverySourceKind sourceKind,
    MiniProgramSourceException? sourceException,
  ) {
    if (sourceKind == MiniProgramDiscoverySourceKind.bundled) {
      return sourceException?.message ??
          'Bundled mini-program assets could not be loaded.';
    }

    final errorCode = sourceException?.errorCode;
    if (errorCode == MiniProgramErrorCodes.backendUnreachable ||
        errorCode == MiniProgramErrorCodes.backendTimeout) {
      return 'No valid offline copy is available.';
    }

    return sourceException?.message ??
        'Mini-program availability could not be determined.';
  }
}
