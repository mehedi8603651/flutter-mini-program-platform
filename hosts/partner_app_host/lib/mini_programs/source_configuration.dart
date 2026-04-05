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

    return PartnerAppHostSourceConfiguration(
      backendApiBaseUri: Uri.parse(rawBackendBaseUrl),
      platform: _defaultPlatform(),
      locale: _defaultLocale(),
      tenantId: _nullIfBlank(rawTenantId),
    );
  }

  final Uri backendApiBaseUri;
  final http.Client? client;
  final String? platform;
  final String? locale;
  final String? tenantId;

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
        hostVersion: hostVersion,
        capabilityRegistry: capabilityRegistry,
      ),
    );
  }

  String get description => 'Local backend ($backendApiBaseUri)';

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
