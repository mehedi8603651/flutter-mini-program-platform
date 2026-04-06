import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import '../capabilities/supported_capabilities.dart';
import 'mini_program_catalog.dart';
import 'mini_program_entry_page.dart';

class MiniProgramListPage extends StatefulWidget {
  const MiniProgramListPage({
    super.key,
    required this.sdkVersion,
    required this.source,
    required this.sourceDescription,
    required this.discoverySourceKind,
    required this.hostBridge,
    required this.capabilityRegistry,
    required this.featureFlagEvaluator,
    required this.cacheBundle,
  });

  final String sdkVersion;
  final MiniProgramSource source;
  final String sourceDescription;
  final MiniProgramDiscoverySourceKind discoverySourceKind;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final MiniProgramCacheBundle cacheBundle;

  @override
  State<MiniProgramListPage> createState() => _MiniProgramListPageState();
}

class _MiniProgramListPageState extends State<MiniProgramListPage> {
  static const MiniProgramDiscoveryResolver _discoveryResolver =
      MiniProgramDiscoveryResolver();

  late Map<String, Future<MiniProgramDiscoveryState>> _discoveryFutures;

  @override
  void initState() {
    super.initState();
    _refreshDiscoveryFutures();
  }

  @override
  void didUpdateWidget(covariant MiniProgramListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.cacheBundle != widget.cacheBundle ||
        oldWidget.discoverySourceKind != widget.discoverySourceKind) {
      _refreshDiscoveryFutures();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Partner App Host')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF123C69), Color(0xFF2F6B89)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portable SDK in a partner lane',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This host stays lean: it supports only the capabilities '
                    'needed by the mini-program and relies on backend delivery '
                    'to receive compatible release lanes for more than one '
                    'portable flow.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _BannerPill(
                        label: 'Delivery: ${widget.sourceDescription}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...PartnerMiniProgramCatalog.availablePrograms.map(
              (program) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MiniProgramCard(
                  program: program,
                  discoveryFuture: _discoveryFutures[program.id]!,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MiniProgramEntryPage(
                          program: program,
                          sdkVersion: widget.sdkVersion,
                          source: widget.source,
                          hostBridge: widget.hostBridge,
                          capabilityRegistry: widget.capabilityRegistry,
                          featureFlagEvaluator: widget.featureFlagEvaluator,
                          cacheBundle: widget.cacheBundle,
                        ),
                      ),
                    );
                  },
                  onPreviewCapabilityFailure: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MiniProgramEntryPage(
                          program: program,
                          sdkVersion: widget.sdkVersion,
                          source: widget.source,
                          hostBridge: widget.hostBridge,
                          capabilityRegistry:
                              partnerAppMissingNavigationCapabilityRegistry,
                          featureFlagEvaluator: widget.featureFlagEvaluator,
                          cacheBundle: widget.cacheBundle,
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

  void _refreshDiscoveryFutures() {
    _discoveryFutures = <String, Future<MiniProgramDiscoveryState>>{
      for (final program in PartnerMiniProgramCatalog.availablePrograms)
        program.id: _discoveryResolver.resolve(
          miniProgramId: program.id,
          source: widget.source,
          manifestCache: widget.cacheBundle.manifestCache,
          screenCache: widget.cacheBundle.screenCache,
          sourceKind: widget.discoverySourceKind,
        ),
    };
  }
}

class _MiniProgramCard extends StatelessWidget {
  const _MiniProgramCard({
    required this.program,
    required this.discoveryFuture,
    required this.onOpen,
    required this.onPreviewCapabilityFailure,
  });

  final PartnerMiniProgramDefinition program;
  final Future<MiniProgramDiscoveryState> discoveryFuture;
  final VoidCallback onOpen;
  final VoidCallback onPreviewCapabilityFailure;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MiniProgramDiscoveryState>(
      future: discoveryFuture,
      builder: (context, snapshot) {
        final isChecking = snapshot.connectionState != ConnectionState.done;
        final discoveryState =
            snapshot.data ??
            MiniProgramDiscoveryState(
              miniProgramId: program.id,
              status: MiniProgramDiscoveryStatus.unavailable,
              message: 'Mini-program availability could not be determined.',
            );
        final canOpen = !isChecking && discoveryState.canOpen;
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
                const SizedBox(height: 12),
                Text(
                  'Backend lane target: ${program.expectedLaneVersion}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DiscoveryBadge(
                      label: isChecking
                          ? 'Checking'
                          : discoveryState.badgeLabel,
                      tone: isChecking
                          ? _DiscoveryTone.neutral
                          : _toneFor(discoveryState.status),
                    ),
                    if (discoveryState.manifest case final manifest?)
                      _DiscoveryBadge(
                        label: 'Resolved v${manifest.version}',
                        tone: _DiscoveryTone.info,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isChecking
                      ? 'Checking backend and offline availability...'
                      : discoveryState.displayMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _messageColor(theme, discoveryState, isChecking),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!isChecking && discoveryState.errorCode != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reason: ${discoveryState.errorCode}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
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
                      onPressed: canOpen ? onOpen : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Open mini-program'),
                    ),
                    OutlinedButton.icon(
                      onPressed: canOpen ? onPreviewCapabilityFailure : null,
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Preview capability failure'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _DiscoveryTone _toneFor(MiniProgramDiscoveryStatus status) {
    switch (status) {
      case MiniProgramDiscoveryStatus.live:
        return _DiscoveryTone.success;
      case MiniProgramDiscoveryStatus.cached:
        return _DiscoveryTone.info;
      case MiniProgramDiscoveryStatus.staleButAllowed:
        return _DiscoveryTone.warning;
      case MiniProgramDiscoveryStatus.unavailable:
        return _DiscoveryTone.error;
    }
  }

  Color _messageColor(
    ThemeData theme,
    MiniProgramDiscoveryState discoveryState,
    bool isChecking,
  ) {
    if (isChecking) {
      return theme.colorScheme.onSurfaceVariant;
    }

    return switch (discoveryState.status) {
      MiniProgramDiscoveryStatus.unavailable => theme.colorScheme.error,
      MiniProgramDiscoveryStatus.staleButAllowed => theme.colorScheme.tertiary,
      MiniProgramDiscoveryStatus.live ||
      MiniProgramDiscoveryStatus.cached => theme.colorScheme.onSurfaceVariant,
    };
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip(this.capability);

  final Capability capability;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(capability.name),
      avatar: const Icon(Icons.link_outlined, size: 18),
    );
  }
}

class _BannerPill extends StatelessWidget {
  const _BannerPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _DiscoveryTone { neutral, success, info, warning, error }

class _DiscoveryBadge extends StatelessWidget {
  const _DiscoveryBadge({required this.label, required this.tone});

  final String label;
  final _DiscoveryTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = switch (tone) {
      _DiscoveryTone.neutral => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      ),
      _DiscoveryTone.success => (
        background: const Color(0xFFDCF5E7),
        foreground: const Color(0xFF126C3A),
      ),
      _DiscoveryTone.info => (
        background: const Color(0xFFDCECFD),
        foreground: const Color(0xFF0E4A7A),
      ),
      _DiscoveryTone.warning => (
        background: const Color(0xFFFFE8BF),
        foreground: const Color(0xFF8A5A00),
      ),
      _DiscoveryTone.error => (
        background: const Color(0xFFFCE1E1),
        foreground: const Color(0xFF9B1C1C),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
