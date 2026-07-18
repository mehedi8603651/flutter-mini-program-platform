import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'models.dart';

final RegExp _miniProgramIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

const List<CapabilityId> _scaffoldCapabilityOrder = <CapabilityId>[
  CapabilityIds.auth,
  CapabilityIds.analytics,
  CapabilityIds.secureApi,
  CapabilityIds.nativeNavigation,
];

const Set<CapabilityId> _knownCapabilities = <CapabilityId>{
  CapabilityIds.auth,
  CapabilityIds.analytics,
  CapabilityIds.secureApi,
  CapabilityIds.nativeNavigation,
};

String normalizeScaffoldMiniProgramId(String rawMiniProgramId) {
  final miniProgramId = rawMiniProgramId.trim();
  if (!_miniProgramIdPattern.hasMatch(miniProgramId)) {
    throw const MiniProgramScaffoldException(
      r'Mini-program ID must match ^[a-z][a-z0-9_]*$',
    );
  }
  return miniProgramId;
}

List<String> normalizeScaffoldCapabilities(Set<String> rawCapabilities) {
  final normalized = rawCapabilities
      .map((capability) => capability.trim())
      .where((capability) => capability.isNotEmpty)
      .toSet();

  if (normalized.isEmpty) {
    throw const MiniProgramScaffoldException(
      'At least one capability must be selected.',
    );
  }

  final unknownCapabilities =
      normalized
          .where((capability) => !_knownCapabilities.contains(capability))
          .toList()
        ..sort();
  if (unknownCapabilities.isNotEmpty) {
    throw MiniProgramScaffoldException(
      'Unknown capability values: ${unknownCapabilities.join(', ')}',
    );
  }

  return _scaffoldCapabilityOrder.where(normalized.contains).toList();
}

String? normalizeScaffoldBackendTemplate(String? rawTemplate) {
  final template = rawTemplate?.trim();
  if (template == null || template.isEmpty) {
    return null;
  }
  if (template != 'mock') {
    throw MiniProgramScaffoldException(
      'Unsupported Publisher API starter template: $rawTemplate',
    );
  }
  return template;
}

String normalizeScaffoldScreenFormat(String rawScreenFormat) {
  final screenFormat = rawScreenFormat.trim();
  if (screenFormat == MiniProgramScreenFormats.mp) {
    return screenFormat;
  }
  throw MiniProgramScaffoldException(
    'Unsupported screen format: $rawScreenFormat',
  );
}

String normalizeScaffoldTitle(String? rawTitle, String miniProgramId) {
  if (rawTitle != null && rawTitle.trim().isNotEmpty) {
    return rawTitle.trim();
  }
  return miniProgramId
      .split('_')
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String normalizeScaffoldDescription(String? rawDescription, String title) {
  if (rawDescription != null && rawDescription.trim().isNotEmpty) {
    return rawDescription.trim();
  }
  return 'Portable $title mini-program.';
}

String scaffoldPascalCase(String value) {
  final segments = value
      .split('_')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) {
    return value;
  }
  return segments
      .map(
        (segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join();
}
