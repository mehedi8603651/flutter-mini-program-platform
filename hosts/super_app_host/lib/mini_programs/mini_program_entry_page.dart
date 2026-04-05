import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'local_mini_program_catalog.dart';

class MiniProgramEntryPage extends StatelessWidget {
  const MiniProgramEntryPage({
    super.key,
    required this.program,
    required this.sdkVersion,
    required this.source,
    required this.hostBridge,
    required this.capabilityRegistry,
    required this.featureFlagEvaluator,
  });

  final LocalMiniProgramDefinition program;
  final String sdkVersion;
  final MiniProgramSource source;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final FeatureFlagEvaluator featureFlagEvaluator;

  @override
  Widget build(BuildContext context) {
    return MiniProgramHost(
      miniProgramId: program.id,
      sdkVersion: sdkVersion,
      source: source,
      hostBridge: hostBridge,
      capabilityRegistry: capabilityRegistry,
      featureFlagEvaluator: featureFlagEvaluator,
      errorBuilder: (context, failure) {
        return Scaffold(
          appBar: AppBar(title: Text(program.title)),
          body: SdkErrorView(failure: failure),
        );
      },
    );
  }
}
