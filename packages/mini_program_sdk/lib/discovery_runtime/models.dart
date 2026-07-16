part of '../mini_program_discovery.dart';

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
