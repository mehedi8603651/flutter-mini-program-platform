import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:partner_app_host/app/app_routes.dart';
import 'package:partner_app_host/app/partner_app_host_app.dart';
import 'package:partner_app_host/bridge/host_bridge_impl.dart';
import 'package:partner_app_host/capabilities/supported_capabilities.dart';
import 'package:partner_app_host/mini_programs/mini_program_catalog.dart';
import 'package:partner_app_host/mini_programs/mini_program_entry_page.dart';
import 'package:partner_app_host/mini_programs/native_feedback_desk_page.dart';
import 'package:partner_app_host/mini_programs/native_profile_review_page.dart';
import 'package:partner_app_host/mini_programs/source_configuration.dart';

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
  testWidgets('shows the partner mini-program list', (tester) async {
    await tester.pumpWidget(
      const PartnerAppHostApp(
        source: _PartnerLaneMiniProgramSource(),
        sourceDescription: 'Local backend (test)',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner App Host'), findsOneWidget);
    expect(find.text('Profile Center'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Feedback Form'), 300);
    expect(find.text('Feedback Form'), findsOneWidget);
    expect(find.text('Open mini-program'), findsWidgets);
  });

  testWidgets('opens profile center in the partner 1.0.0 lane', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: MiniProgramEntryPage(
          program: PartnerMiniProgramCatalog.profileCenter,
          sdkVersion: partnerAppHostSdkVersion,
          source: const _PartnerLaneMiniProgramSource(),
          hostBridge: HostBridgeImpl(navigatorKey: navigatorKey),
          capabilityRegistry: partnerAppCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Open Native Edit Screen'));

    expect(find.text('Portable account module'), findsOneWidget);
    expect(
      find.text(
        'This mini-program is delivered through the shared SDK and keeps '
        'native work behind the host bridge.',
      ),
      findsOneWidget,
    );
    expect(find.text('Active release: Profile Center v1.1.0'), findsNothing);
  });

  testWidgets('opens feedback form in the partner 1.0.0 lane', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: MiniProgramEntryPage(
          program: PartnerMiniProgramCatalog.feedbackForm,
          sdkVersion: partnerAppHostSdkVersion,
          source: const _PartnerLaneMiniProgramSource(),
          hostBridge: HostBridgeImpl(navigatorKey: navigatorKey),
          capabilityRegistry: partnerAppCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Validate and continue'));

    expect(find.text('Portable feedback lane'), findsOneWidget);
    expect(find.text('Release lane: Feedback Form v1.0.0'), findsOneWidget);
    expect(find.text('Track feedback view'), findsOneWidget);
  });

  testWidgets('shows the SDK fallback when partner capabilities are missing', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: MiniProgramEntryPage(
          program: PartnerMiniProgramCatalog.profileCenter,
          sdkVersion: partnerAppHostSdkVersion,
          source: const _MissingCapabilityMiniProgramSource(),
          hostBridge: HostBridgeImpl(navigatorKey: navigatorKey),
          capabilityRegistry: partnerAppMissingNavigationCapabilityRegistry,
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

  testWidgets('partner bridge maps profile_editor to its native review page', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final bridge = HostBridgeImpl(navigatorKey: navigatorKey);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.nativeProfileReview) {
            final args = settings.arguments! as Map<String, dynamic>;
            return MaterialPageRoute<void>(
              builder: (_) => NativeProfileReviewPage(initialArgs: args),
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

    expect(find.text('Partner Profile Review'), findsOneWidget);
    expect(find.text('User ID: guest_001'), findsOneWidget);

    await tester.tap(find.text('Apply partner-side update'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result.isSuccess, isTrue);
    expect(result.data['approved'], isTrue);
    expect(result.data['userId'], 'guest_001');
  });

  testWidgets(
    'partner bridge maps feedback_follow_up to its native desk page',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final bridge = HostBridgeImpl(navigatorKey: navigatorKey);

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.nativeFeedbackDesk) {
              final args = settings.arguments! as Map<String, dynamic>;
              return MaterialPageRoute<void>(
                builder: (_) => NativeFeedbackDeskPage(initialArgs: args),
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

      expect(find.text('Partner Feedback Desk'), findsOneWidget);
      expect(find.text('Requested by: feedback_form'), findsOneWidget);

      await tester.tap(find.text('Open partner follow-up ticket'));
      await tester.pumpAndSettle();

      final result = await resultFuture;
      expect(result.isSuccess, isTrue);
      expect(result.data['ticketCreated'], isTrue);
      expect(result.data['channel'], 'mini_program');
    },
  );

  test('source configuration sends partner delivery context', () async {
    late Uri requestUri;
    final client = MockClient((request) async {
      requestUri = request.url;
      return http.Response(
        '{"id":"profile_center","version":"1.0.0","entry":"profile_center_home","contractVersion":"1.0.0","sdkVersionRange":">=1.0.0 <2.0.0","requiredCapabilities":["analytics","native_navigation"]}',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final configuration = PartnerAppHostSourceConfiguration(
      backendApiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      client: client,
      platform: 'android',
      locale: 'en-US',
      tenantId: 'campus-demo',
    );
    final source = configuration.buildSource(
      hostAppId: partnerAppHostId,
      sdkVersion: partnerAppHostSdkVersion,
      hostVersion: partnerAppHostVersion,
      capabilityRegistry: partnerAppCapabilityRegistry,
    );

    final manifest = await source.loadManifest('profile_center');

    expect(manifest.version, '1.0.0');
    expect(requestUri.path, '/api/manifests/profile_center/latest.json');
    expect(requestUri.queryParameters['hostApp'], partnerAppHostId);
    expect(requestUri.queryParameters['sdkVersion'], partnerAppHostSdkVersion);
    expect(requestUri.queryParameters['hostVersion'], partnerAppHostVersion);
    expect(requestUri.queryParameters['platform'], 'android');
    expect(requestUri.queryParameters['locale'], 'en-US');
    expect(requestUri.queryParameters['tenantId'], 'campus-demo');
    expect(
      requestUri.queryParameters['capabilities'],
      'analytics,native_navigation',
    );
  });
}

class _PartnerLaneMiniProgramSource implements MiniProgramSource {
  const _PartnerLaneMiniProgramSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    switch (miniProgramId) {
      case 'profile_center':
        return const MiniProgramManifest(
          id: 'profile_center',
          version: '1.0.0',
          entry: 'profile_center_home',
          contractVersion: '1.0.0',
          sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
          requiredCapabilities: <Capability>[
            Capability.analytics,
            Capability.nativeNavigation,
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
          version: '1.0.0',
          entry: 'feedback_form_home',
          contractVersion: '1.0.0',
          sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
          requiredCapabilities: <Capability>[
            Capability.analytics,
            Capability.nativeNavigation,
          ],
          fallback: MiniProgramFallback(
            strategy: MiniProgramFallbackStrategy.errorView,
            message:
                'Feedback Form is temporarily unavailable in this host app.',
          ),
        );
      default:
        throw StateError(
          'Unsupported partner test mini-program "$miniProgramId".',
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
                    'data':
                        'This mini-program is delivered through the shared SDK '
                        'and keeps native work behind the host bridge.',
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
                    'data': 'Release lane: Feedback Form v1.0.0',
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
          'Unsupported partner test mini-program "$miniProgramId".',
        );
    }
  }
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
              'This screen should not render when partner capabilities are '
              'missing.',
        },
      },
    };
  }
}
