import 'package:mini_program_contracts/mini_program_contracts.dart';

class PartnerMiniProgramDefinition {
  const PartnerMiniProgramDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredCapabilities,
    required this.expectedLaneVersion,
  });

  final String id;
  final String title;
  final String description;
  final List<Capability> requiredCapabilities;
  final String expectedLaneVersion;
}

abstract final class PartnerMiniProgramCatalog {
  static const PartnerMiniProgramDefinition profileCenter =
      PartnerMiniProgramDefinition(
        id: 'profile_center',
        title: 'Profile Center',
        description:
            'The same portable Stac mini-program delivered into a smaller '
            'partner host lane through backend selection.',
        requiredCapabilities: <Capability>[
          Capability.analytics,
          Capability.nativeNavigation,
        ],
        expectedLaneVersion: '1.0.0',
      );

  static const List<PartnerMiniProgramDefinition> availablePrograms =
      <PartnerMiniProgramDefinition>[profileCenter];
}
