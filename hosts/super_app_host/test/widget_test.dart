import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:super_app_host/app/app_routes.dart';
import 'package:super_app_host/app/super_app_host_app.dart';
import 'package:super_app_host/bridge/host_bridge_impl.dart';
import 'package:super_app_host/capabilities/supported_capabilities.dart';
import 'package:super_app_host/mini_programs/local_mini_program_catalog.dart';
import 'package:super_app_host/mini_programs/mini_program_entry_page.dart';
import 'package:super_app_host/mini_programs/native_profile_editor_page.dart';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxSteps = 100,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var index = 0; index < maxSteps; index++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }

  throw TestFailure('Timed out waiting for finder: $finder');
}

void main() {
  testWidgets('shows the local mini-program list', (tester) async {
    await tester.pumpWidget(const SuperAppHostApp());
    await tester.pumpAndSettle();

    expect(find.text('Super App Host'), findsOneWidget);
    expect(find.text('Profile Center'), findsOneWidget);
    expect(find.text('Open mini-program'), findsOneWidget);
    expect(find.text('Delivery: Bundled assets'), findsOneWidget);
  });

  testWidgets('opens the local profile center mini-program', (tester) async {
    await tester.pumpWidget(const SuperAppHostApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open mini-program'));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Open Native Edit Screen'));

    expect(find.text('Portable account module'), findsOneWidget);
    expect(find.text('Open Native Edit Screen'), findsOneWidget);
  });

  testWidgets('shows the SDK fallback when host capabilities are missing', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: MiniProgramEntryPage(
          program: LocalMiniProgramCatalog.profileCenter,
          sdkVersion: superAppHostSdkVersion,
          source: const _MissingCapabilityMiniProgramSource(),
          hostBridge: HostBridgeImpl(navigatorKey: navigatorKey),
          capabilityRegistry: superAppMissingNavigationCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Mini-program unavailable'));

    expect(find.text('Mini-program unavailable'), findsOneWidget);
    expect(
      find.text('Profile Center is temporarily unavailable in this host app.'),
      findsOneWidget,
    );
    expect(
      find.text('Error code: ${MiniProgramErrorCodes.unsupportedCapability}'),
      findsOneWidget,
    );
  });

  testWidgets('host bridge maps profile_editor to the native editor page', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final bridge = HostBridgeImpl(navigatorKey: navigatorKey);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.nativeProfileEditor) {
            final args = settings.arguments! as Map<String, dynamic>;
            return MaterialPageRoute<void>(
              builder: (_) => NativeProfileEditorPage(initialArgs: args),
              settings: settings,
            );
          }

          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox.shrink()),
            settings: settings,
          );
        },
      ),
    );

    final resultFuture = bridge.openNativeScreen(
      const OpenNativeScreenActionPayload(
        route: 'profile_editor',
        args: <String, dynamic>{
          'userId': 'guest_001',
          'source': 'profile_center',
        },
        expectResult: true,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Native Profile Editor'), findsOneWidget);
    expect(find.text('User ID: guest_001'), findsOneWidget);

    await tester.tap(find.text('Save profile changes'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result.isSuccess, isTrue);
    expect(result.data['saved'], isTrue);
    expect(result.data['userId'], 'guest_001');
  });
}

class _MissingCapabilityMiniProgramSource implements MiniProgramSource {
  const _MissingCapabilityMiniProgramSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return const MiniProgramManifest(
      id: 'profile_center',
      version: '1.0.0',
      entry: 'profile_center_home',
      contractVersion: '1.0.0',
      sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
      requiredCapabilities: <Capability>[Capability.nativeNavigation],
      fallback: MiniProgramFallback(
        strategy: MiniProgramFallbackStrategy.errorView,
        message: 'Profile Center is temporarily unavailable in this host app.',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return const <String, dynamic>{
      'type': 'scaffold',
      'body': <String, dynamic>{
        'type': 'center',
        'child': <String, dynamic>{
          'type': 'text',
          'data':
              'This screen should not render when capabilities are missing.',
        },
      },
    };
  }
}
