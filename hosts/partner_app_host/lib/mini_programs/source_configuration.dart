import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

class PartnerAppHostSourceConfiguration {
  PartnerAppHostSourceConfiguration({
    required this.backendApiBaseUri,
    this.client,
    this.platform,
    this.locale,
    this.tenantId,
    this.hostVersionOverride,
    this.pinnedVersion,
  });

  factory PartnerAppHostSourceConfiguration.fromEnvironment() {
    const rawBackendBaseUrl = String.fromEnvironment(
      'PARTNER_APP_BACKEND_BASE_URL',
      defaultValue: 'http://127.0.0.1:8080/api/',
    );
    const rawTenantId = String.fromEnvironment(
      'PARTNER_APP_TENANT_ID',
      defaultValue: '',
    );
    const rawHostVersion = String.fromEnvironment(
      'PARTNER_APP_HOST_VERSION',
      defaultValue: '',
    );
    const rawPlatform = String.fromEnvironment(
      'PARTNER_APP_PLATFORM',
      defaultValue: '',
    );
    const rawLocale = String.fromEnvironment(
      'PARTNER_APP_LOCALE',
      defaultValue: '',
    );
    const rawPinnedVersion = String.fromEnvironment(
      'PARTNER_APP_PINNED_VERSION',
      defaultValue: '',
    );

    return PartnerAppHostSourceConfiguration(
      backendApiBaseUri: Uri.parse(rawBackendBaseUrl),
      platform: _nullIfBlank(rawPlatform) ?? _defaultPlatform(),
      locale: _nullIfBlank(rawLocale) ?? _defaultLocale(),
      tenantId: _nullIfBlank(rawTenantId),
      hostVersionOverride: _nullIfBlank(rawHostVersion),
      pinnedVersion: _nullIfBlank(rawPinnedVersion),
    );
  }

  final Uri backendApiBaseUri;
  final http.Client? client;
  final String? platform;
  final String? locale;
  final String? tenantId;
  final String? hostVersionOverride;
  final String? pinnedVersion;

  MiniProgramSource buildSource({
    required String hostAppId,
    required String sdkVersion,
    required String hostVersion,
    required CapabilityRegistry capabilityRegistry,
  }) {
    return HttpMiniProgramSource(
      apiBaseUri: backendApiBaseUri,
      client: client,
      manifestRequestQueryParametersBuilder: (_) => _buildManifestContext(
        hostAppId: hostAppId,
        sdkVersion: sdkVersion,
        hostVersion: hostVersionOverride ?? hostVersion,
        capabilityRegistry: capabilityRegistry,
      ),
    );
  }

  String get description {
    final labels = <String>[
      if (hostVersionOverride != null) 'hostVersion=$hostVersionOverride',
      if (tenantId != null) 'tenantId=$tenantId',
      if (pinnedVersion != null) 'pinnedVersion=$pinnedVersion',
    ];
    final suffix = labels.isEmpty ? '' : '; ${labels.join(', ')}';
    return 'Local backend ($backendApiBaseUri$suffix)';
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

    final pinnedVersionValue = pinnedVersion;
    if (pinnedVersionValue != null) {
      queryParameters['pinnedVersion'] = pinnedVersionValue;
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
