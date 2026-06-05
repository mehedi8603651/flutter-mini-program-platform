import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

class PartnerMiniProgramDefinition {
  const PartnerMiniProgramDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredCapabilities,
    required this.expectedLaneVersion,
    this.isBackendDiscovered = false,
  });

  factory PartnerMiniProgramDefinition.fromPublishedSummary(
    PublishedMiniProgramSummary summary,
  ) {
    return PartnerMiniProgramDefinition(
      id: summary.id,
      title: summary.title,
      description: summary.description,
      requiredCapabilities: summary.requiredCapabilities,
      expectedLaneVersion: summary.resolvedVersion,
      isBackendDiscovered: true,
    );
  }

  final String id;
  final String title;
  final String description;
  final List<CapabilityId> requiredCapabilities;
  final String expectedLaneVersion;
  final bool isBackendDiscovered;
}

abstract final class PartnerMiniProgramCatalog {
  static const PartnerMiniProgramDefinition mpProfileCenter =
      PartnerMiniProgramDefinition(
        id: 'mp_profile_center',
        title: 'Mp Profile Center',
        description:
            'A lightweight Mp profile flow delivered into a smaller partner '
            'host lane through backend selection.',
        requiredCapabilities: <CapabilityId>[CapabilityIds.analytics],
        expectedLaneVersion: '1.0.0',
      );

  static const PartnerMiniProgramDefinition mpRewardsCenter =
      PartnerMiniProgramDefinition(
        id: 'mp_rewards_center',
        title: 'Mp Rewards Center',
        description:
            'An Mp rewards flow with auth, backend state, paged data, and '
            'manual Load more behavior.',
        requiredCapabilities: <CapabilityId>[
          CapabilityIds.auth,
          CapabilityIds.analytics,
        ],
        expectedLaneVersion: '1.0.0',
      );

  static const List<PartnerMiniProgramDefinition> availablePrograms =
      <PartnerMiniProgramDefinition>[mpProfileCenter, mpRewardsCenter];
}
