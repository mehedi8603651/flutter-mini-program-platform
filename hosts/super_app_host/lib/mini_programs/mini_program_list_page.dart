import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import '../capabilities/supported_capabilities.dart';
import 'local_mini_program_catalog.dart';

class MiniProgramListPage extends StatefulWidget {
  const MiniProgramListPage({
    super.key,
    required this.config,
    required this.cacheBundle,
    required this.catalogClient,
    required this.sourceDescription,
    required this.discoverySourceKind,
  });

  final MiniProgramConfig config;
  final MiniProgramCacheBundle cacheBundle;
  final PublishedMiniProgramCatalogClient? catalogClient;
  final String sourceDescription;
  final MiniProgramDiscoverySourceKind discoverySourceKind;

  @override
  State<MiniProgramListPage> createState() => _MiniProgramListPageState();
}

class _MiniProgramListPageState extends State<MiniProgramListPage> {
  static const MiniProgramDiscoveryResolver _discoveryResolver =
      MiniProgramDiscoveryResolver();

  late Map<String, Future<MiniProgramDiscoveryState>> _discoveryFutures;
  Future<List<LocalMiniProgramDefinition>>? _remoteProgramsFuture;

  @override
  void initState() {
    super.initState();
    _refreshProgramState();
  }

  @override
  void didUpdateWidget(covariant MiniProgramListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.source != widget.config.source ||
        oldWidget.cacheBundle != widget.cacheBundle ||
        oldWidget.discoverySourceKind != widget.discoverySourceKind ||
        oldWidget.catalogClient != widget.catalogClient) {
      _refreshProgramState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super App Host'),
        actions: [
          IconButton(
            tooltip: 'Refresh mini-programs',
            onPressed: _refreshPrograms,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
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
                      'Delivery: ${widget.sourceDescription}',
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
            ..._buildProgramSection(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProgramSection() {
    if (widget.catalogClient == null) {
      return _buildProgramCards(LocalMiniProgramCatalog.availablePrograms);
    }

    return <Widget>[
      FutureBuilder<List<LocalMiniProgramDefinition>>(
        future: _remoteProgramsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CatalogNotice(
                  message:
                      'Remote catalog discovery failed. Falling back to the bundled list.',
                  tone: _DiscoveryTone.warning,
                  actionLabel: 'Retry discovery',
                  onAction: _refreshPrograms,
                ),
                const SizedBox(height: 16),
                ..._buildProgramCards(
                  LocalMiniProgramCatalog.availablePrograms,
                ),
              ],
            );
          }

          final programs =
              snapshot.data ?? const <LocalMiniProgramDefinition>[];
          if (programs.isEmpty) {
            return const _CatalogNotice(
              message:
                  'No compatible backend-delivered mini-programs are currently available.',
              tone: _DiscoveryTone.neutral,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildProgramCards(programs),
          );
        },
      ),
    ];
  }

  List<Widget> _buildProgramCards(List<LocalMiniProgramDefinition> programs) {
    return programs
        .map(
          (program) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _MiniProgramCard(
              program: program,
              discoveryFuture: _discoveryFutures[program.id]!,
              onOpen: () {
                MiniProgramScope.of(context).openMiniProgram<void>(
                  appId: program.id,
                  title: program.title,
                );
              },
              onPreviewCapabilityFailure: () {
                final previewRuntime = _buildPreviewRuntime(
                  superAppMissingNavigationCapabilityRegistry,
                );
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MiniProgramPage(
                      miniProgramId: program.id,
                      title: program.title,
                      runtime: previewRuntime,
                    ),
                  ),
                );
              },
            ),
          ),
        )
        .toList(growable: false);
  }

  void _refreshProgramState() {
    _discoveryFutures = <String, Future<MiniProgramDiscoveryState>>{};
    _registerDiscoveryFutures(LocalMiniProgramCatalog.availablePrograms);

    final remoteCatalogClient = widget.catalogClient;
    if (remoteCatalogClient == null) {
      _remoteProgramsFuture = null;
      return;
    }

    _remoteProgramsFuture = _loadRemotePrograms(remoteCatalogClient);
  }

  void _refreshPrograms() {
    setState(_refreshProgramState);
  }

  Future<List<LocalMiniProgramDefinition>> _loadRemotePrograms(
    PublishedMiniProgramCatalogClient catalogClient,
  ) async {
    final catalog = await catalogClient.listAvailableMiniPrograms();
    final programs = catalog.entries
        .map(LocalMiniProgramDefinition.fromPublishedSummary)
        .toList(growable: false);
    _registerDiscoveryFutures(programs);
    return programs;
  }

  void _registerDiscoveryFutures(
    Iterable<LocalMiniProgramDefinition> programs,
  ) {
    for (final program in programs) {
      _discoveryFutures.putIfAbsent(
        program.id,
        () => _discoveryResolver.resolve(
          miniProgramId: program.id,
          source: widget.config.source,
          manifestCache: widget.cacheBundle.manifestCache,
          screenCache: widget.cacheBundle.screenCache,
          sourceKind: widget.discoverySourceKind,
        ),
      );
    }
  }

  MiniProgramRuntime _buildPreviewRuntime(CapabilityRegistry registry) {
    return MiniProgramRuntime(
      sdkVersion: widget.config.sdkVersion,
      source: widget.config.source,
      hostBridge: widget.config.hostBridge,
      capabilityRegistry: registry,
      featureFlagEvaluator: widget.config.featureFlagEvaluator,
      cacheBundle: widget.cacheBundle,
      logger: widget.config.logger,
      disposeSource: false,
    );
  }
}

class _MiniProgramCard extends StatelessWidget {
  const _MiniProgramCard({
    required this.program,
    required this.discoveryFuture,
    required this.onOpen,
    required this.onPreviewCapabilityFailure,
  });

  final LocalMiniProgramDefinition program;
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
                if (program.isBackendDiscovered &&
                    program.resolvedVersion != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Discovered release: v${program.resolvedVersion}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
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
                        label: 'v${manifest.version}',
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

  final CapabilityId capability;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(capability),
      avatar: const Icon(Icons.verified_outlined, size: 18),
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

class _CatalogNotice extends StatelessWidget {
  const _CatalogNotice({
    required this.message,
    required this.tone,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final _DiscoveryTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              tone == _DiscoveryTone.warning
                  ? Icons.wifi_off_rounded
                  : Icons.info_outline_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: Theme.of(context).textTheme.bodyLarge),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
