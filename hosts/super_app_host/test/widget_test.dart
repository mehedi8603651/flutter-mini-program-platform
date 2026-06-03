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
import 'package:super_app_host/mini_programs/native_feedback_inbox_page.dart';
import 'package:super_app_host/mini_programs/native_profile_editor_page.dart';
import 'package:super_app_host/mini_programs/source_configuration.dart';
import 'package:super_app_host/services/auth_session_service.dart';
import 'package:super_app_host/services/secure_api_service.dart';

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

  final visibleTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText())
      .whereType<String>()
      .toList();
  throw TestFailure(
    'Timed out waiting for finder: $finder\nVisible text: $visibleTexts',
  );
}

void main() {
  testWidgets('renders backend-discovered mini-program cards in remote mode', (
    tester,
  ) async {
    late Uri requestUri;
    final catalogClient = PublishedMiniProgramCatalogClient(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      queryParameters: const <String, String>{
        'hostApp': superAppHostId,
        'sdkVersion': superAppHostSdkVersion,
      },
      client: MockClient((request) async {
        requestUri = request.url;
        return http.Response(
          '''
          {
            "responseType":"mini_program_catalog",
            "statusCode":200,
            "entries":[
              {
                "id":"coupon_center",
                "title":"Coupon Center",
                "description":"A backend-discovered portable coupon flow.",
                "entry":"coupon_center_home",
                "resolvedVersion":"1.0.0",
                "requiredCapabilities":["analytics","native_navigation"]
              }
            ]
          }
          ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      SuperAppHostApp(
        source: const _CatalogDiscoveryMiniProgramSource(),
        catalogClient: catalogClient,
        sourceDescription: 'Local backend (test)',
        discoverySourceKind: MiniProgramDiscoverySourceKind.remote,
        cacheBundle: MiniProgramCacheBundle.inMemory(),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Coupon Center'));

    expect(requestUri.path, '/api/discovery/mini-programs.json');
    expect(find.text('Coupon Center'), findsOneWidget);
    expect(find.text('Discovered release: v1.0.0'), findsOneWidget);
  });

  testWidgets('shows the local mini-program list', (tester) async {
    await tester.pumpWidget(
      SuperAppHostApp(cacheBundle: MiniProgramCacheBundle.inMemory()),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Super App Host'));

    expect(find.text('Super App Host'), findsOneWidget);
    expect(find.text('Profile Center'), findsOneWidget);
    expect(find.text('Delivery: Bundled assets'), findsOneWidget);
    expect(find.text('Cached'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Feedback Form'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Feedback Form'), findsOneWidget);
    expect(find.text('Cached'), findsWidgets);
    expect(find.text('Open mini-program'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Mp Profile Center'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Mp Profile Center'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mp Rewards Center'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Mp Rewards Center'), findsOneWidget);
  });

  testWidgets(
    'opens a mini-program from the host list through MiniProgramPage',
    (tester) async {
      await tester.pumpWidget(
        SuperAppHostApp(
          source: const _SuperLaneMiniProgramSource(),
          sourceDescription: 'Injected source',
          cacheBundle: MiniProgramCacheBundle.inMemory(),
        ),
      );
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Open mini-program'));
      await tester.scrollUntilVisible(
        find.text('Open mini-program').first,
        300,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open mini-program').first);
      await tester.pumpAndSettle();

      expect(find.text('Portable account module'), findsOneWidget);
      expect(find.text('Open Native Edit Screen'), findsOneWidget);
    },
  );

  testWidgets('opens the local profile center mini-program', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: MiniProgramEntryPage(
          program: LocalMiniProgramCatalog.profileCenter,
          sdkVersion: superAppHostSdkVersion,
          source: const _SuperLaneMiniProgramSource(),
          hostBridge: HostBridgeImpl(
            navigatorKey: navigatorKey,
            secureApiService: _RecordingSecureApiService(),
          ),
          capabilityRegistry: superAppCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          cacheBundle: MiniProgramCacheBundle.inMemory(),
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
          source: const _SuperLaneMiniProgramSource(),
          hostBridge: HostBridgeImpl(
            navigatorKey: navigatorKey,
            secureApiService: _RecordingSecureApiService(),
          ),
          capabilityRegistry: superAppCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          cacheBundle: MiniProgramCacheBundle.inMemory(),
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
          hostBridge: HostBridgeImpl(
            navigatorKey: navigatorKey,
            secureApiService: _RecordingSecureApiService(),
          ),
          capabilityRegistry: superAppMissingNavigationCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          cacheBundle: MiniProgramCacheBundle.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
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
    final bridge = HostBridgeImpl(
      navigatorKey: navigatorKey,
      secureApiService: _RecordingSecureApiService(),
    );

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
    final bridge = HostBridgeImpl(
      navigatorKey: navigatorKey,
      secureApiService: _RecordingSecureApiService(),
    );

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

  test(
    'host bridge delegates secure feedback submission to the secure API service',
    () async {
      final secureApiService = _RecordingSecureApiService();
      final bridge = HostBridgeImpl(
        navigatorKey: GlobalKey<NavigatorState>(),
        secureApiService: secureApiService,
      );

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
      expect(secureApiService.lastPayload?.endpoint, 'feedback/submit');
      expect(result.data['status'], 'recorded');
    },
  );

  test('secure API service posts host session context to the backend', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        '{"message":"Secure feedback submission recorded.","submissionId":"super_secure_001","status":"accepted","hostApp":"super_app_host"}',
        201,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final service = BackendSecureApiService(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      authSessionService: LocalAuthSessionService.seeded(
        userId: 'super_demo_user',
        accessToken: 'super-demo-access-token',
        displayName: 'Super App User',
        tenantId: 'internal-demo',
      ),
      hostAppId: superAppHostId,
      hostVersion: '1.4.0',
      client: client,
    );

    final result = await service.call(
      const CallSecureApiActionPayload(
        endpoint: 'feedback/submit',
        body: <String, dynamic>{
          'source': 'feedback_form',
          'flow': 'portable_feedback',
          'message': 'Validated feedback payload from portable UI.',
        },
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/secure/feedback/submit');
    expect(capturedRequest.headers['x-host-app'], superAppHostId);
    expect(capturedRequest.headers['x-host-version'], '1.4.0');
    expect(capturedRequest.headers['x-host-user-id'], 'super_demo_user');
    expect(capturedRequest.headers['x-host-tenant-id'], 'internal-demo');
    expect(
      capturedRequest.headers['authorization'],
      'Bearer super-demo-access-token',
    );
    expect(result.data['submissionId'], 'super_secure_001');
  });

  test(
    'secure API service fails before network when no host session exists',
    () async {
      var networkCalled = false;
      final client = MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });
      final service = BackendSecureApiService(
        apiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
        authSessionService: LocalAuthSessionService.signedOut(),
        hostAppId: superAppHostId,
        hostVersion: '1.4.0',
        client: client,
      );

      final result = await service.call(
        const CallSecureApiActionPayload(
          endpoint: 'feedback/submit',
          body: <String, dynamic>{
            'source': 'feedback_form',
            'message': 'Validated feedback payload from portable UI.',
          },
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.errorCode, MiniProgramErrorCodes.secureApiSessionMissing);
      expect(result.data['failureCategory'], 'auth');
      expect(result.data['retryable'], isFalse);
      expect(networkCalled, isFalse);
    },
  );

  test('secure API service reports backend timeout as retryable', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('{}', 200);
    });
    final service = BackendSecureApiService(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      authSessionService: LocalAuthSessionService.seeded(
        userId: 'super_demo_user',
        accessToken: 'super-demo-access-token',
        displayName: 'Super App User',
      ),
      hostAppId: superAppHostId,
      hostVersion: '1.4.0',
      client: client,
      requestTimeout: const Duration(milliseconds: 10),
    );

    final result = await service.call(
      const CallSecureApiActionPayload(
        endpoint: 'feedback/submit',
        body: <String, dynamic>{
          'source': 'feedback_form',
          'message': 'Validated feedback payload from portable UI.',
        },
      ),
    );

    expect(result.isFailure, isTrue);
    expect(result.errorCode, MiniProgramErrorCodes.backendTimeout);
    expect(result.data['failureCategory'], 'transport');
    expect(result.data['retryable'], isTrue);
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
      requiredCapabilities: <CapabilityId>[CapabilityIds.nativeNavigation],
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

class _SuperLaneMiniProgramSource implements MiniProgramSource {
  const _SuperLaneMiniProgramSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    switch (miniProgramId) {
      case 'profile_center':
        return const MiniProgramManifest(
          id: 'profile_center',
          version: '1.1.0',
          entry: 'profile_center_home',
          contractVersion: '1.0.0',
          sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
          requiredCapabilities: <CapabilityId>[
            CapabilityIds.analytics,
            CapabilityIds.nativeNavigation,
          ],
          fallback: MiniProgramFallback(
            strategy: MiniProgramFallbackStrategy.errorView,
            message:
                'Profile Center is temporarily unavailable in this host app.',
          ),
        );
      case 'feedback_form':
        return const MiniProgramManifest(
          id: 'feedback_form',
          version: '1.1.0',
          entry: 'feedback_form_home',
          contractVersion: '1.0.0',
          sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
          requiredCapabilities: <CapabilityId>[
            CapabilityIds.analytics,
            CapabilityIds.secureApi,
            CapabilityIds.nativeNavigation,
          ],
          fallback: MiniProgramFallback(
            strategy: MiniProgramFallbackStrategy.errorView,
            message:
                'Feedback Form is temporarily unavailable in this host app.',
          ),
        );
      default:
        throw StateError(
          'Unsupported super-host mini-program "$miniProgramId".',
        );
    }
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    switch (miniProgramId) {
      case 'profile_center':
        return const <String, dynamic>{
          'type': 'scaffold',
          'appBar': <String, dynamic>{
            'type': 'appBar',
            'title': <String, dynamic>{
              'type': 'text',
              'data': 'Profile Center',
            },
          },
          'body': <String, dynamic>{
            'type': 'safeArea',
            'child': <String, dynamic>{
              'type': 'singleChildScrollView',
              'padding': <String, dynamic>{
                'left': 24.0,
                'top': 24.0,
                'right': 24.0,
                'bottom': 24.0,
              },
              'child': <String, dynamic>{
                'type': 'column',
                'crossAxisAlignment': 'start',
                'children': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'text',
                    'data': 'Portable account module',
                  },
                  <String, dynamic>{'type': 'sizedBox', 'height': 12.0},
                  <String, dynamic>{
                    'type': 'text',
                    'data': 'Active release: Profile Center v1.1.0',
                  },
                  <String, dynamic>{'type': 'sizedBox', 'height': 24.0},
                  <String, dynamic>{
                    'type': 'filledButton',
                    'child': <String, dynamic>{
                      'type': 'text',
                      'data': 'Open Native Edit Screen',
                    },
                    'onPressed': <String, dynamic>{
                      'actionType': 'hostAction',
                      'requestId': 'profile-open-native-editor',
                      'action': 'openNativeScreen',
                      'payload': <String, dynamic>{
                        'route': 'profile_editor',
                        'args': <String, dynamic>{
                          'userId': 'guest_001',
                          'source': 'profile_center',
                        },
                        'expectResult': true,
                      },
                    },
                  },
                ],
              },
            },
          },
        };
      case 'feedback_form':
        return const <String, dynamic>{
          'type': 'scaffold',
          'appBar': <String, dynamic>{
            'type': 'appBar',
            'title': <String, dynamic>{'type': 'text', 'data': 'Feedback Form'},
          },
          'body': <String, dynamic>{
            'type': 'safeArea',
            'child': <String, dynamic>{
              'type': 'singleChildScrollView',
              'padding': <String, dynamic>{
                'left': 24.0,
                'top': 24.0,
                'right': 24.0,
                'bottom': 24.0,
              },
              'child': <String, dynamic>{
                'type': 'column',
                'crossAxisAlignment': 'start',
                'children': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'text',
                    'data': 'Portable feedback lane',
                  },
                  <String, dynamic>{'type': 'sizedBox', 'height': 12.0},
                  <String, dynamic>{
                    'type': 'text',
                    'data': 'Release lane: Feedback Form v1.1.0',
                  },
                  <String, dynamic>{'type': 'sizedBox', 'height': 24.0},
                  <String, dynamic>{
                    'type': 'filledButton',
                    'child': <String, dynamic>{
                      'type': 'text',
                      'data': 'Validate and continue',
                    },
                    'onPressed': <String, dynamic>{
                      'actionType': 'hostAction',
                      'requestId': 'feedback-open-follow-up',
                      'action': 'openNativeScreen',
                      'payload': <String, dynamic>{
                        'route': 'feedback_follow_up',
                        'args': <String, dynamic>{
                          'source': 'feedback_form',
                          'channel': 'mini_program',
                        },
                        'expectResult': true,
                      },
                    },
                  },
                  <String, dynamic>{'type': 'sizedBox', 'height': 12.0},
                  <String, dynamic>{
                    'type': 'outlinedButton',
                    'child': <String, dynamic>{
                      'type': 'text',
                      'data': 'Track feedback view',
                    },
                  },
                ],
              },
            },
          },
        };
      default:
        throw StateError(
          'Unsupported super-host mini-program "$miniProgramId".',
        );
    }
  }
}

class _CatalogDiscoveryMiniProgramSource implements MiniProgramSource {
  const _CatalogDiscoveryMiniProgramSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return MiniProgramManifest(
      id: miniProgramId,
      version: '1.0.0',
      entry: '${miniProgramId}_home',
      contractVersion: '1.0.0',
      sdkVersionRange: const SdkVersionRange(value: '>=1.0.0 <2.0.0'),
      requiredCapabilities: const <CapabilityId>[
        CapabilityIds.analytics,
        CapabilityIds.nativeNavigation,
      ],
      fallback: MiniProgramFallback(
        strategy: MiniProgramFallbackStrategy.errorView,
        message: '$miniProgramId is temporarily unavailable in this host app.',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return const <String, dynamic>{'type': 'text', 'data': 'unused'};
  }
}

class _RecordingSecureApiService implements SecureApiService {
  CallSecureApiActionPayload? get lastPayload => _lastPayload;

  CallSecureApiActionPayload? _lastPayload;

  @override
  Future<HostActionResult> call(CallSecureApiActionPayload payload) async {
    _lastPayload = payload;
    return HostActionResult.success(
      actionName: ActionNames.callSecureApi,
      data: <String, dynamic>{
        'status': 'recorded',
        'endpoint': payload.endpoint,
      },
    );
  }
}
