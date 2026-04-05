import 'package:mini_program_contracts/mini_program_contracts.dart';

class LocalMiniProgramDefinition {
  const LocalMiniProgramDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredCapabilities,
  });

  final String id;
  final String title;
  final String description;
  final List<Capability> requiredCapabilities;
}

abstract final class LocalMiniProgramCatalog {
  static const LocalMiniProgramDefinition profileCenter =
      LocalMiniProgramDefinition(
        id: 'profile_center',
        title: 'Profile Center',
        description:
            'A mobile-friendly account module authored in Stac DSL and '
            'rendered through mini_program_sdk inside the first-party host.',
        requiredCapabilities: <Capability>[
          Capability.analytics,
          Capability.nativeNavigation,
        ],
      );

  static const LocalMiniProgramDefinition feedbackForm =
      LocalMiniProgramDefinition(
        id: 'feedback_form',
        title: 'Feedback Form',
        description:
            'A portable feedback flow authored in Stac DSL that validates '
            'locally, tracks analytics through the shared bridge, and opens a '
            'host-owned follow-up screen.',
        requiredCapabilities: <Capability>[
          Capability.analytics,
          Capability.nativeNavigation,
        ],
      );

  static const List<LocalMiniProgramDefinition> availablePrograms =
      <LocalMiniProgramDefinition>[profileCenter, feedbackForm];

  static LocalMiniProgramDefinition byId(String miniProgramId) {
    for (final program in availablePrograms) {
      if (program.id == miniProgramId) {
        return program;
      }
    }

    throw StateError('Unknown local mini-program "$miniProgramId".');
  }
}
