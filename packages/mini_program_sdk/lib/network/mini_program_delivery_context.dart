import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Shared manifest-delivery query context for backend-hosted mini-programs.
@immutable
class MiniProgramDeliveryContext {
  const MiniProgramDeliveryContext({
    required this.hostApp,
    required this.sdkVersion,
    required this.hostVersion,
    required this.capabilities,
    this.platform,
    this.locale,
    this.tenantId,
    this.pinnedVersion,
  });

  final String hostApp;
  final String sdkVersion;
  final String hostVersion;
  final Set<CapabilityId> capabilities;
  final String? platform;
  final String? locale;
  final String? tenantId;
  final String? pinnedVersion;

  Map<String, String> toQueryParameters() {
    final queryParameters = <String, String>{
      'hostApp': hostApp,
      'sdkVersion': sdkVersion,
      'hostVersion': hostVersion,
      'capabilities': _serializeCapabilities(capabilities),
    };

    final platformValue = _nullIfBlank(platform);
    if (platformValue != null) {
      queryParameters['platform'] = platformValue;
    }

    final localeValue = _nullIfBlank(locale);
    if (localeValue != null) {
      queryParameters['locale'] = localeValue;
    }

    final tenantIdValue = _nullIfBlank(tenantId);
    if (tenantIdValue != null) {
      queryParameters['tenantId'] = tenantIdValue;
    }

    final pinnedVersionValue = _nullIfBlank(pinnedVersion);
    if (pinnedVersionValue != null) {
      queryParameters['pinnedVersion'] = pinnedVersionValue;
    }

    return queryParameters;
  }

  static String _serializeCapabilities(Set<CapabilityId> capabilities) {
    final wireValues = CapabilityIds.normalizeAll(capabilities).toList()
      ..sort();
    return wireValues.join(',');
  }

  static String? _nullIfBlank(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
