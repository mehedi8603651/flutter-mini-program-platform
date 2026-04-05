import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

final CapabilityRegistry superAppCapabilityRegistry = CapabilityRegistry(
  const <Capability>[
    Capability.auth,
    Capability.analytics,
    Capability.secureApi,
    Capability.nativeNavigation,
  ],
);

final CapabilityRegistry superAppMissingNavigationCapabilityRegistry =
    CapabilityRegistry(const <Capability>[
      Capability.auth,
      Capability.analytics,
    ]);
