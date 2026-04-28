import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import '../bridge/host_bridge_impl.dart';
import '../capabilities/supported_capabilities.dart';
import '../mini_programs/native_feedback_inbox_page.dart';
import '../mini_programs/local_mini_program_source.dart';
import '../mini_programs/mini_program_list_page.dart';
import '../mini_programs/native_profile_editor_page.dart';
import '../mini_programs/source_configuration.dart';
import '../services/auth_session_service.dart';
import 'app_routes.dart';

const String superAppHostId = 'super_app_host';
const String superAppHostSdkVersion = '1.0.0';
const String superAppHostVersion = '1.0.0';

class SuperAppHostApp extends StatefulWidget {
  const SuperAppHostApp({
    super.key,
    this.source,
    this.catalogClient,
    this.sourceDescription,
    this.sourceConfiguration,
    this.authSessionService,
    this.capabilityRegistry,
    this.featureFlagEvaluator = const AllowAllFeatureFlagEvaluator(),
    this.cacheBundle,
    this.discoverySourceKind,
  });

  final MiniProgramSource? source;
  final PublishedMiniProgramCatalogClient? catalogClient;
  final String? sourceDescription;
  final SuperAppHostSourceConfiguration? sourceConfiguration;
  final AuthSessionService? authSessionService;
  final CapabilityRegistry? capabilityRegistry;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final MiniProgramCacheBundle? cacheBundle;
  final MiniProgramDiscoverySourceKind? discoverySourceKind;

  @override
  State<SuperAppHostApp> createState() => _SuperAppHostAppState();
}

class _SuperAppHostAppState extends State<SuperAppHostApp> {
  late final GlobalKey<NavigatorState> _navigatorKey;
  late final MiniProgramSource _source;
  late final String _sourceDescription;
  late final CapabilityRegistry _capabilityRegistry;
  late final HostBridge _hostBridge;
  late final MiniProgramCacheBundle _cacheBundle;
  late final MiniProgramConfig _miniProgramConfig;
  late final MiniProgramDiscoverySourceKind _discoverySourceKind;
  late final PublishedMiniProgramCatalogClient? _catalogClient;

  @override
  void initState() {
    super.initState();
    _navigatorKey = GlobalKey<NavigatorState>();
    _cacheBundle = widget.cacheBundle ?? MiniProgramCacheBundle.inMemory();
    _capabilityRegistry =
        widget.capabilityRegistry ?? superAppCapabilityRegistry;
    final sourceConfiguration =
        widget.sourceConfiguration ??
        SuperAppHostSourceConfiguration.fromEnvironment();
    _source =
        widget.source ??
        sourceConfiguration.buildSource(
          hostAppId: superAppHostId,
          sdkVersion: superAppHostSdkVersion,
          hostVersion: superAppHostVersion,
          capabilityRegistry: _capabilityRegistry,
        );
    _sourceDescription =
        widget.sourceDescription ??
        (widget.source != null
            ? 'Injected source'
            : sourceConfiguration.description);
    _catalogClient =
        widget.catalogClient ??
        (widget.source != null
            ? null
            : sourceConfiguration.buildCatalogClient(
                hostAppId: superAppHostId,
                sdkVersion: superAppHostSdkVersion,
                hostVersion: superAppHostVersion,
                capabilityRegistry: _capabilityRegistry,
              ));
    _discoverySourceKind =
        widget.discoverySourceKind ??
        (widget.source != null
            ? _inferDiscoverySourceKind(widget.source!)
            : _sourceKindForMode(sourceConfiguration.mode));
    final authSessionService =
        widget.authSessionService ??
        _buildAuthSessionService(sourceConfiguration);
    _hostBridge = HostBridgeImpl(
      navigatorKey: _navigatorKey,
      secureApiService: sourceConfiguration.buildSecureApiService(
        hostAppId: superAppHostId,
        hostVersion: superAppHostVersion,
        authSessionService: authSessionService,
      ),
    );
    _miniProgramConfig = MiniProgramConfig(
      sdkVersion: superAppHostSdkVersion,
      source: _source,
      hostBridge: _hostBridge,
      capabilityRegistry: _capabilityRegistry,
      featureFlagEvaluator: widget.featureFlagEvaluator,
      cacheBundle: _cacheBundle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MiniProgramScope(
      config: _miniProgramConfig,
      child: _buildMaterialApp(
        home: MiniProgramListPage(
          config: _miniProgramConfig,
          cacheBundle: _cacheBundle,
          catalogClient: _catalogClient,
          sourceDescription: _sourceDescription,
          discoverySourceKind: _discoverySourceKind,
        ),
      ),
    );
  }

  Widget _buildMaterialApp({required Widget home}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F6D67),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Super App Host',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F0E8),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.nativeProfileEditor:
            final arguments = _coerceArguments(settings.arguments);
            return MaterialPageRoute<void>(
              builder: (_) => NativeProfileEditorPage(initialArgs: arguments),
              settings: settings,
            );
          case AppRoutes.nativeFeedbackInbox:
            final arguments = _coerceArguments(settings.arguments);
            return MaterialPageRoute<void>(
              builder: (_) => NativeFeedbackInboxPage(initialArgs: arguments),
              settings: settings,
            );
          default:
            return null;
        }
      },
      home: home,
    );
  }

  MiniProgramDiscoverySourceKind _inferDiscoverySourceKind(
    MiniProgramSource source,
  ) {
    if (source is LocalMiniProgramSource) {
      return MiniProgramDiscoverySourceKind.bundled;
    }

    return MiniProgramDiscoverySourceKind.remote;
  }

  MiniProgramDiscoverySourceKind _sourceKindForMode(
    SuperAppHostSourceMode mode,
  ) {
    switch (mode) {
      case SuperAppHostSourceMode.assets:
        return MiniProgramDiscoverySourceKind.bundled;
      case SuperAppHostSourceMode.localBackend:
        return MiniProgramDiscoverySourceKind.remote;
    }
  }

  AuthSessionService _buildAuthSessionService(
    SuperAppHostSourceConfiguration sourceConfiguration,
  ) {
    const rawAuthState = String.fromEnvironment(
      'SUPER_APP_AUTH_STATE',
      defaultValue: 'authenticated',
    );

    return LocalAuthSessionService.seeded(
      userId: 'super_demo_user',
      accessToken: 'super-demo-access-token',
      displayName: 'Super App User',
      tenantId: sourceConfiguration.tenantId,
      mode: _parseAuthMode(rawAuthState),
    );
  }

  LocalAuthSessionSeedMode _parseAuthMode(String rawValue) {
    switch (rawValue.trim().toLowerCase()) {
      case 'signed_out':
      case 'signed-out':
      case 'signedout':
        return LocalAuthSessionSeedMode.signedOut;
      case 'expired':
        return LocalAuthSessionSeedMode.expired;
      case 'blocked':
        return LocalAuthSessionSeedMode.blocked;
      case 'authenticated':
      default:
        return LocalAuthSessionSeedMode.authenticated;
    }
  }

  Map<String, dynamic> _coerceArguments(Object? arguments) {
    if (arguments is Map<String, dynamic>) {
      return arguments;
    }

    if (arguments is Map) {
      return arguments.map((key, value) => MapEntry(key.toString(), value));
    }

    return const <String, dynamic>{};
  }
}
