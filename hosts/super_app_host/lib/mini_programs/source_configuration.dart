import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'local_mini_program_source.dart';

enum SuperAppHostSourceMode { assets, localBackend }

class SuperAppHostSourceConfiguration {
  SuperAppHostSourceConfiguration({
    required this.mode,
    this.backendApiBaseUri,
    this.platform,
    this.locale,
    this.tenantId,
  });

  factory SuperAppHostSourceConfiguration.fromEnvironment() {
    const rawMode = String.fromEnvironment(
      'SUPER_APP_SOURCE_MODE',
      defaultValue: 'assets',
    );
    const rawBackendBaseUrl = String.fromEnvironment(
      'SUPER_APP_BACKEND_BASE_URL',
      defaultValue: 'http://127.0.0.1:8080/api/',
    );
    const rawTenantId = String.fromEnvironment(
      'SUPER_APP_TENANT_ID',
      defaultValue: '',
    );

    return SuperAppHostSourceConfiguration(
      mode: _parseMode(rawMode),
      backendApiBaseUri: Uri.parse(rawBackendBaseUrl),
      platform: _defaultPlatform(),
      locale: _defaultLocale(),
      tenantId: _nullIfBlank(rawTenantId),
    );
  }

  final SuperAppHostSourceMode mode;
  final Uri? backendApiBaseUri;
  final String? platform;
  final String? locale;
  final String? tenantId;

  MiniProgramSource buildSource({
    required String hostAppId,
    required String sdkVersion,
    required String hostVersion,
    required CapabilityRegistry capabilityRegistry,
  }) {
    switch (mode) {
      case SuperAppHostSourceMode.assets:
        return const LocalMiniProgramSource();
      case SuperAppHostSourceMode.localBackend:
        final apiBaseUri = backendApiBaseUri;
        if (apiBaseUri == null) {
          throw StateError(
            'A backend API base URI is required for local backend source mode.',
          );
        }

        return HttpMiniProgramSource(
          apiBaseUri: apiBaseUri,
          manifestRequestQueryParametersBuilder: (_) => _buildManifestContext(
            hostAppId: hostAppId,
            sdkVersion: sdkVersion,
            hostVersion: hostVersion,
            capabilityRegistry: capabilityRegistry,
          ),
        );
    }
  }

  String get description {
    switch (mode) {
      case SuperAppHostSourceMode.assets:
        return 'Bundled assets';
      case SuperAppHostSourceMode.localBackend:
        return 'Local backend (${backendApiBaseUri ?? 'unconfigured'})';
    }
  }

  static SuperAppHostSourceMode _parseMode(String rawMode) {
    switch (rawMode.trim().toLowerCase()) {
      case 'backend':
      case 'local_backend':
      case 'local-backend':
        return SuperAppHostSourceMode.localBackend;
      case 'assets':
      default:
        return SuperAppHostSourceMode.assets;
    }
  }

  Map<String, String> _buildManifestContext({
    required String hostAppId,
    required String sdkVersion,
    required String hostVersion,
    required CapabilityRegistry capabilityRegistry,
  }) {
    final queryParameters = <String, String>{
      'hostApp': hostAppId,
      'sdkVersion': sdkVersion,
      'hostVersion': hostVersion,
      'capabilities': _serializeCapabilities(
        capabilityRegistry.supportedCapabilities,
      ),
    };

    final platformValue = platform;
    if (platformValue != null) {
      queryParameters['platform'] = platformValue;
    }

    final localeValue = locale;
    if (localeValue != null) {
      queryParameters['locale'] = localeValue;
    }

    final tenantIdValue = tenantId;
    if (tenantIdValue != null) {
      queryParameters['tenantId'] = tenantIdValue;
    }

    return queryParameters;
  }

  static String _defaultPlatform() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String? _defaultLocale() {
    final locale = ui.PlatformDispatcher.instance.locale;
    final tag = locale.toLanguageTag();
    return tag.isEmpty ? null : tag;
  }

  static String? _nullIfBlank(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _serializeCapabilities(Set<Capability> capabilities) {
    final wireValues =
        capabilities.map((capability) => capability.wireValue).toList()..sort();
    return wireValues.join(',');
  }
}
