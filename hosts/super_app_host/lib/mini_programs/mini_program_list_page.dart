import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import '../capabilities/supported_capabilities.dart';
import 'local_mini_program_catalog.dart';
import 'mini_program_entry_page.dart';

class MiniProgramListPage extends StatelessWidget {
  const MiniProgramListPage({
    super.key,
    required this.sdkVersion,
    required this.source,
    required this.sourceDescription,
    required this.hostBridge,
    required this.capabilityRegistry,
    required this.featureFlagEvaluator,
  });

  final String sdkVersion;
  final MiniProgramSource source;
  final String sourceDescription;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final FeatureFlagEvaluator featureFlagEvaluator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Super App Host')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF0F6D67), Color(0xFF56A79A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portable mini-program preview',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This first-party host proves the shared SDK can validate, '
                    'render, and bridge multiple mobile mini-programs through '
                    'the same runtime and host bridge.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Delivery: $sourceDescription',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...LocalMiniProgramCatalog.availablePrograms.map(
              (program) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MiniProgramCard(
                  program: program,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MiniProgramEntryPage(
                          program: program,
                          sdkVersion: sdkVersion,
                          source: source,
                          hostBridge: hostBridge,
                          capabilityRegistry: capabilityRegistry,
                          featureFlagEvaluator: featureFlagEvaluator,
                        ),
                      ),
                    );
                  },
                  onPreviewCapabilityFailure: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MiniProgramEntryPage(
                          program: program,
                          sdkVersion: sdkVersion,
                          source: source,
                          hostBridge: hostBridge,
                          capabilityRegistry:
                              superAppMissingNavigationCapabilityRegistry,
                          featureFlagEvaluator: featureFlagEvaluator,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniProgramCard extends StatelessWidget {
  const _MiniProgramCard({
    required this.program,
    required this.onOpen,
    required this.onPreviewCapabilityFailure,
  });

  final LocalMiniProgramDefinition program;
  final VoidCallback onOpen;
  final VoidCallback onPreviewCapabilityFailure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              program.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(program.description, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: program.requiredCapabilities
                  .map(_CapabilityChip.new)
                  .toList(),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Open mini-program'),
                ),
                OutlinedButton.icon(
                  onPressed: onPreviewCapabilityFailure,
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Preview capability failure'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip(this.capability);

  final Capability capability;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(capability.name),
      avatar: const Icon(Icons.verified_outlined, size: 18),
    );
  }
}
