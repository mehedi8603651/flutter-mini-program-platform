import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

final CapabilityRegistry superAppCapabilityRegistry =
    CapabilityRegistry(const <CapabilityId>[
      CapabilityIds.auth,
      CapabilityIds.analytics,
      CapabilityIds.secureApi,
      CapabilityIds.nativeNavigation,
    ]);

final CapabilityRegistry superAppMissingNavigationCapabilityRegistry =
    CapabilityRegistry(const <CapabilityId>[
      CapabilityIds.auth,
      CapabilityIds.analytics,
    ]);
