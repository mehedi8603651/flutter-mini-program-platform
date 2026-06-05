import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

class LocalMiniProgramDefinition {
  const LocalMiniProgramDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredCapabilities,
    this.isBackendDiscovered = false,
    this.resolvedVersion,
  });

  factory LocalMiniProgramDefinition.fromPublishedSummary(
    PublishedMiniProgramSummary summary,
  ) {
    return LocalMiniProgramDefinition(
      id: summary.id,
      title: summary.title,
      description: summary.description,
      requiredCapabilities: summary.requiredCapabilities,
      isBackendDiscovered: true,
      resolvedVersion: summary.resolvedVersion,
    );
  }

  final String id;
  final String title;
  final String description;
  final List<CapabilityId> requiredCapabilities;
  final bool isBackendDiscovered;
  final String? resolvedVersion;
}

abstract final class LocalMiniProgramCatalog {
  static const LocalMiniProgramDefinition mpProfileCenter =
      LocalMiniProgramDefinition(
        id: 'mp_profile_center',
        title: 'Mp Profile Center',
        description:
            'A bundled Mp JSON profile fixture that proves the SDK-owned '
            'renderer can open lightweight screens.',
        requiredCapabilities: <CapabilityId>[CapabilityIds.analytics],
      );

  static const LocalMiniProgramDefinition mpRewardsCenter =
      LocalMiniProgramDefinition(
        id: 'mp_rewards_center',
        title: 'Mp Rewards Center',
        description:
            'A bundled Mp JSON rewards fixture covering auth, backend state, '
            'paged data, and manual Load more behavior.',
        requiredCapabilities: <CapabilityId>[
          CapabilityIds.auth,
          CapabilityIds.analytics,
        ],
      );

  static const List<LocalMiniProgramDefinition> availablePrograms =
      <LocalMiniProgramDefinition>[mpProfileCenter, mpRewardsCenter];

  static LocalMiniProgramDefinition byId(String miniProgramId) {
    for (final program in availablePrograms) {
      if (program.id == miniProgramId) {
        return program;
      }
    }

    throw StateError('Unknown local mini-program "$miniProgramId".');
  }
}
