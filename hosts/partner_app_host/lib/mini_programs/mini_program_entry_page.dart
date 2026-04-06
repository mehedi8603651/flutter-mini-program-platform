import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program_catalog.dart';

class MiniProgramEntryPage extends StatelessWidget {
  const MiniProgramEntryPage({
    super.key,
    required this.program,
    required this.sdkVersion,
    required this.source,
    required this.hostBridge,
    required this.capabilityRegistry,
    required this.featureFlagEvaluator,
    this.cacheBundle,
  });

  final PartnerMiniProgramDefinition program;
  final String sdkVersion;
  final MiniProgramSource source;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final MiniProgramCacheBundle? cacheBundle;

  @override
  Widget build(BuildContext context) {
    return MiniProgramHost(
      miniProgramId: program.id,
      sdkVersion: sdkVersion,
      source: source,
      hostBridge: hostBridge,
      capabilityRegistry: capabilityRegistry,
      featureFlagEvaluator: featureFlagEvaluator,
      assetCache: cacheBundle?.assetCache,
      manifestCache: cacheBundle?.manifestCache,
      screenCache: cacheBundle?.screenCache,
      errorBuilder: (context, failure) {
        return Scaffold(
          appBar: AppBar(title: Text(program.title)),
          body: SdkErrorView(failure: failure),
        );
      },
    );
  }
}
