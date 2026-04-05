import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

final CapabilityRegistry partnerAppCapabilityRegistry = CapabilityRegistry(
  const <Capability>[Capability.analytics, Capability.nativeNavigation],
);

final CapabilityRegistry partnerAppMissingNavigationCapabilityRegistry =
    CapabilityRegistry(const <Capability>[Capability.analytics]);
