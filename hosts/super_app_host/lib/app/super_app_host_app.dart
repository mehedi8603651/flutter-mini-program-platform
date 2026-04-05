import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import '../bridge/host_bridge_impl.dart';
import '../capabilities/supported_capabilities.dart';
import '../mini_programs/mini_program_list_page.dart';
import '../mini_programs/native_profile_editor_page.dart';
import '../mini_programs/source_configuration.dart';
import 'app_routes.dart';

const String superAppHostId = 'super_app_host';
const String superAppHostSdkVersion = '1.0.0';

class SuperAppHostApp extends StatefulWidget {
  const SuperAppHostApp({
    super.key,
    this.source,
    this.sourceDescription,
    this.sourceConfiguration,
    this.capabilityRegistry,
    this.featureFlagEvaluator = const AllowAllFeatureFlagEvaluator(),
  });

  final MiniProgramSource? source;
  final String? sourceDescription;
  final SuperAppHostSourceConfiguration? sourceConfiguration;
  final CapabilityRegistry? capabilityRegistry;
  final FeatureFlagEvaluator featureFlagEvaluator;

  @override
  State<SuperAppHostApp> createState() => _SuperAppHostAppState();
}

class _SuperAppHostAppState extends State<SuperAppHostApp> {
  late final GlobalKey<NavigatorState> _navigatorKey;
  late final MiniProgramSource _source;
  late final String _sourceDescription;
  late final CapabilityRegistry _capabilityRegistry;
  late final HostBridge _hostBridge;

  @override
  void initState() {
    super.initState();
    _navigatorKey = GlobalKey<NavigatorState>();
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
          capabilityRegistry: _capabilityRegistry,
        );
    _sourceDescription =
        widget.sourceDescription ??
        (widget.source != null
            ? 'Injected source'
            : sourceConfiguration.description);
    _hostBridge = HostBridgeImpl(navigatorKey: _navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
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
          default:
            return null;
        }
      },
      home: MiniProgramListPage(
        sdkVersion: superAppHostSdkVersion,
        source: _source,
        sourceDescription: _sourceDescription,
        hostBridge: _hostBridge,
        capabilityRegistry: _capabilityRegistry,
        featureFlagEvaluator: widget.featureFlagEvaluator,
      ),
    );
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
