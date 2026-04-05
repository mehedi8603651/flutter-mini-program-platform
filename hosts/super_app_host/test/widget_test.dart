import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:super_app_host/app/app_routes.dart';
import 'package:super_app_host/app/super_app_host_app.dart';
import 'package:super_app_host/bridge/host_bridge_impl.dart';
import 'package:super_app_host/capabilities/supported_capabilities.dart';
import 'package:super_app_host/mini_programs/local_mini_program_catalog.dart';
import 'package:super_app_host/mini_programs/mini_program_entry_page.dart';
import 'package:super_app_host/mini_programs/local_mini_program_source.dart';
import 'package:super_app_host/mini_programs/native_feedback_inbox_page.dart';
import 'package:super_app_host/mini_programs/native_profile_editor_page.dart';
import 'package:super_app_host/mini_programs/source_configuration.dart';

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
    expect(find.text('Delivery: Bundled assets'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Feedback Form'), 300);
    expect(find.text('Feedback Form'), findsOneWidget);
    expect(find.text('Open mini-program'), findsWidgets);
  });

  testWidgets('opens the local profile center mini-program', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: MiniProgramEntryPage(
          program: LocalMiniProgramCatalog.profileCenter,
          sdkVersion: superAppHostSdkVersion,
          source: const LocalMiniProgramSource(),
          hostBridge: HostBridgeImpl(navigatorKey: navigatorKey),
          capabilityRegistry: superAppCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Open Native Edit Screen'));

    expect(find.text('Portable account module'), findsOneWidget);
    expect(find.text('Active release: Profile Center v1.1.0'), findsOneWidget);
    expect(find.text('Open Native Edit Screen'), findsOneWidget);
  });

  testWidgets('opens the local feedback form mini-program', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: MiniProgramEntryPage(
          program: LocalMiniProgramCatalog.feedbackForm,
          sdkVersion: superAppHostSdkVersion,
          source: const LocalMiniProgramSource(),
          hostBridge: HostBridgeImpl(navigatorKey: navigatorKey),
          capabilityRegistry: superAppCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Validate and continue'));

    expect(find.text('Portable feedback lane'), findsOneWidget);
    expect(find.text('Release lane: Feedback Form v1.1.0'), findsOneWidget);
    expect(find.text('Track feedback view'), findsOneWidget);
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
    await _pumpUntilFound(tester, find.text('Host capability mismatch'));

    expect(find.text('Host capability mismatch'), findsOneWidget);
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

  testWidgets('host bridge maps feedback_follow_up to the native inbox page', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final bridge = HostBridgeImpl(navigatorKey: navigatorKey);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.nativeFeedbackInbox) {
            final args = settings.arguments! as Map<String, dynamic>;
            return MaterialPageRoute<void>(
              builder: (_) => NativeFeedbackInboxPage(initialArgs: args),
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
        route: 'feedback_follow_up',
        args: <String, dynamic>{
          'source': 'feedback_form',
          'channel': 'mini_program',
        },
        expectResult: true,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Native Feedback Inbox'), findsOneWidget);
    expect(find.text('Requested by: feedback_form'), findsOneWidget);

    await tester.tap(find.text('Queue host follow-up'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result.isSuccess, isTrue);
    expect(result.data['queued'], isTrue);
    expect(result.data['channel'], 'mini_program');
  });

  test('host bridge maps secure feedback submission to a host API result', () async {
    final bridge = HostBridgeImpl(navigatorKey: GlobalKey<NavigatorState>());

    final result = await bridge.callSecureApi(
      const CallSecureApiActionPayload(
        endpoint: 'feedback/submit',
        body: <String, dynamic>{
          'source': 'feedback_form',
          'message': 'Validated feedback payload from portable UI.',
        },
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.actionName, ActionNames.callSecureApi);
    expect(result.data['host'], 'super_app_host');
    expect(result.data['status'], 'accepted');
  });

  test('source configuration sends super-app delivery context', () async {
    late Uri requestUri;
    final client = MockClient((request) async {
      requestUri = request.url;
      return http.Response(
        '{"id":"profile_center","version":"1.0.0","entry":"profile_center_home","contractVersion":"1.0.0","sdkVersionRange":">=1.0.0 <2.0.0","requiredCapabilities":["analytics","native_navigation"]}',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final configuration = SuperAppHostSourceConfiguration(
      mode: SuperAppHostSourceMode.localBackend,
      backendApiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      client: client,
      platform: 'android',
      locale: 'en-US',
      tenantId: 'internal-demo',
      hostVersionOverride: '1.4.0',
      pinnedVersion: '1.0.0',
    );
    final source = configuration.buildSource(
      hostAppId: superAppHostId,
      sdkVersion: superAppHostSdkVersion,
      hostVersion: superAppHostVersion,
      capabilityRegistry: superAppCapabilityRegistry,
    );

    final manifest = await source.loadManifest('profile_center');

    expect(manifest.version, '1.0.0');
    expect(requestUri.path, '/api/manifests/profile_center/latest.json');
    expect(requestUri.queryParameters['hostApp'], superAppHostId);
    expect(requestUri.queryParameters['sdkVersion'], superAppHostSdkVersion);
    expect(requestUri.queryParameters['hostVersion'], '1.4.0');
    expect(requestUri.queryParameters['platform'], 'android');
    expect(requestUri.queryParameters['locale'], 'en-US');
    expect(requestUri.queryParameters['tenantId'], 'internal-demo');
    expect(requestUri.queryParameters['pinnedVersion'], '1.0.0');
    expect(
      requestUri.queryParameters['capabilities'],
      'analytics,auth,native_navigation,secure_api',
    );
    expect(configuration.description, contains('hostVersion=1.4.0'));
    expect(configuration.description, contains('tenantId=internal-demo'));
    expect(configuration.description, contains('pinnedVersion=1.0.0'));
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
