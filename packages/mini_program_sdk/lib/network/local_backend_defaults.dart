import 'package:flutter/foundation.dart';

/// Shared local artifact endpoint defaults for generated host apps.
///
/// The host app can always override the resolved base URL with an explicit
/// legacy-named `MINI_PROGRAM_BACKEND_BASE_URL` value. When only a host and/or
/// port needs to change for local development, prefer
/// `MINI_PROGRAM_BACKEND_HOST` and `MINI_PROGRAM_BACKEND_PORT`.
abstract final class LocalMiniProgramBackendDefaults {
  static const int defaultPort = 8080;
  static const String defaultPath = '/api/';

  static String defaultHost({TargetPlatform? platform, bool isWeb = kIsWeb}) {
    if (isWeb) {
      return '127.0.0.1';
    }

    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return '127.0.0.1';
    }
  }

  static Uri resolveBaseUri({
    String configuredBaseUrl = '',
    String configuredHost = '',
    int configuredPort = defaultPort,
    String path = defaultPath,
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final trimmedBaseUrl = configuredBaseUrl.trim();
    if (trimmedBaseUrl.isNotEmpty) {
      return Uri.parse(trimmedBaseUrl);
    }

    final host = configuredHost.trim().isNotEmpty
        ? configuredHost.trim()
        : defaultHost(platform: platform, isWeb: isWeb);

    return Uri(
      scheme: 'http',
      host: host,
      port: configuredPort,
      path: _normalizePath(path),
    );
  }

  static String _normalizePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return defaultPath;
    }
    final withLeadingSlash = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return withLeadingSlash.endsWith('/')
        ? withLeadingSlash
        : '$withLeadingSlash/';
  }
}
