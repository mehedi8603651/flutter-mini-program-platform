import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MiniProgramHost', () {
    testWidgets('renders entry screen JSON on the happy path', (tester) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJson: _helloScreenJson,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hello from profile center'), findsOneWidget);
    });

    testWidgets('shows fallback error for unsupported SDK versions', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJson: _helloScreenJson,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '2.0.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SDK update required'), findsOneWidget);
      expect(
        find.textContaining('requires SDK >=1.0.0 <2.0.0'),
        findsOneWidget,
      );
    });

    testWidgets('shows fallback error when required capabilities are missing', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(
          requiredCapabilities: const [Capability.nativeNavigation],
        ),
        screenJson: _helloScreenJson,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Host capability mismatch'), findsOneWidget);
      expect(
        find.textContaining('required capabilities: native_navigation'),
        findsOneWidget,
      );
    });

    testWidgets('surfaces backend manifest rejection details', (tester) async {
      const source = _FailingManifestSource(
        exception: MiniProgramSourceException(
          message:
              'Mini-program "profile_center" is not enabled for host "partner_app_host".',
          errorCode: 'host_not_enabled',
          statusCode: 412,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Release unavailable'), findsOneWidget);
      expect(
        find.textContaining('not enabled for host "partner_app_host"'),
        findsOneWidget,
      );
      expect(find.text('Error code: host_not_enabled'), findsOneWidget);
    });

    testWidgets('surfaces backend transport failures cleanly', (tester) async {
      const source = _FailingManifestSource(
        exception: MiniProgramSourceException(
          message:
              'Failed to reach the mini-program backend while loading manifest.',
          errorCode: 'backend_unreachable',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Backend unavailable'), findsOneWidget);
      expect(
        find.text(
          'Failed to reach the mini-program backend while loading manifest.',
        ),
        findsOneWidget,
      );
      expect(find.text('Error code: backend_unreachable'), findsOneWidget);
    });

    testWidgets('shows an offline notice when stale cached content is rendered', (
      tester,
    ) async {
      final manifest = _buildManifest();
      final manifestCache = InMemoryManifestCache();
      final screenCache = InMemoryScreenCache();

      await manifestCache.write(
        CachedManifestEntry(
          miniProgramId: 'profile_center',
          manifest: manifest,
          cachedAt: DateTime.now(),
        ),
      );
      await screenCache.write(
        CachedScreenEntry(
          miniProgramId: 'profile_center',
          version: manifest.version,
          screenId: manifest.entry,
          screenJson: _helloScreenJson,
          cachedAt: DateTime.now(),
        ),
      );

      const source = _FailingManifestSource(
        exception: MiniProgramSourceException(
          message:
              'Failed to reach the mini-program backend while loading manifest.',
          errorCode: 'backend_unreachable',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: manifestCache,
            screenCache: screenCache,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hello from profile center'), findsOneWidget);
      expect(
        find.textContaining(
          'Showing cached content while the backend is unavailable.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows fallback error when feature flags are disabled', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(featureFlags: const ['profile_center_v2']),
        screenJson: _helloScreenJson,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            featureFlagEvaluator: const _RejectAllFeatureFlags(),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('Required feature flags are disabled'),
        findsOneWidget,
      );
    });

    testWidgets('shows fallback error when root screen JSON cannot render', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJson: const <String, dynamic>{'unexpected': 'shape'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mini-program unavailable'), findsOneWidget);
      expect(find.textContaining('Failed to render screen'), findsOneWidget);
    });

    testWidgets('dispatches hostAction through the registered parser', (
      tester,
    ) async {
      final bridge = _FakeHostBridge();
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJson: _actionScreenJson,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: bridge,
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Track Event'));
      await tester.pumpAndSettle();

      expect(bridge.trackEventCalls, hasLength(1));
      expect(bridge.trackEventCalls.single.name, 'profile_opened');
    });

    testWidgets('dispatches secure_api through the registered parser', (
      tester,
    ) async {
      final bridge = _FakeHostBridge();
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(
          requiredCapabilities: const [Capability.secureApi],
        ),
        screenJson: _secureApiScreenJson,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'feedback_form',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: bridge,
            capabilityRegistry: CapabilityRegistry(const [
              Capability.secureApi,
            ]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Securely'));
      await tester.pumpAndSettle();

      expect(bridge.callSecureApiCalls, hasLength(1));
      expect(bridge.callSecureApiCalls.single.endpoint, 'feedback/submit');
    });

    testWidgets('opens a second mini-program screen and pops back by screenId', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJsonById: const <String, Map<String, dynamic>>{
          'profile/home': _openDetailsScreenJson,
          'profile/details': _detailsScreenJson,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Open details'), findsOneWidget);

      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();

      expect(find.text('Portable details screen'), findsOneWidget);
      expect(find.text('Open details'), findsNothing);

      await tester.tap(find.text('Back to first screen'));
      await tester.pumpAndSettle();

      expect(find.text('Open details'), findsOneWidget);
      expect(find.text('Portable details screen'), findsNothing);
    });

    testWidgets('replaces the current mini-program screen by screenId', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJsonById: const <String, Map<String, dynamic>>{
          'profile/home': _replaceDetailsScreenJson,
          'profile/details': _detailsScreenJson,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Replace with details'), findsOneWidget);

      await tester.tap(find.text('Replace with details'));
      await tester.pumpAndSettle();

      expect(find.text('Portable details screen'), findsOneWidget);
      expect(find.text('Replace with details'), findsNothing);
    });

    testWidgets('shows fallback error when a routed screen cannot be loaded', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJsonById: const <String, Map<String, dynamic>>{
          'profile/home': _missingScreenActionJson,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open missing screen'));
      await tester.pumpAndSettle();

      expect(find.text('Mini-program unavailable'), findsOneWidget);
      expect(find.textContaining('profile/missing'), findsOneWidget);
    });

    testWidgets('resets the mini-program stack to a target screen', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJsonById: const <String, Map<String, dynamic>>{
          'profile/home': _resetToDetailsScreenJson,
          'profile/details': _detailsScreenJson,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset to details'));
      await tester.pumpAndSettle();

      expect(find.text('Portable details screen'), findsOneWidget);
      expect(find.text('Reset to details'), findsNothing);
    });

    testWidgets('pops to the root mini-program screen', (tester) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJsonById: const <String, Map<String, dynamic>>{
          'profile/home': _openDetailsScreenJson,
          'profile/details': _openConfirmScreenJson,
          'profile/confirm': _popToRootScreenJson,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open confirm screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pop to root'));
      await tester.pumpAndSettle();

      expect(find.text('Open details'), findsOneWidget);
      expect(find.text('Portable confirm screen'), findsNothing);
      expect(find.text('Open confirm screen'), findsNothing);
    });

    testWidgets('pops to an existing mini-program screen in the stack', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJsonById: const <String, Map<String, dynamic>>{
          'profile/home': _openDetailsScreenJson,
          'profile/details': _openConfirmScreenJson,
          'profile/confirm': _popToDetailsScreenJson,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open confirm screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pop to details'));
      await tester.pumpAndSettle();

      expect(find.text('Open confirm screen'), findsOneWidget);
      expect(find.text('Portable confirm screen'), findsNothing);
      expect(find.text('Open details'), findsNothing);
    });

    testWidgets('fails cleanly when popToScreen target is not in the stack', (
      tester,
    ) async {
      final source = _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJsonById: const <String, Map<String, dynamic>>{
          'profile/home': _popToMissingStackScreenJson,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramHost(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            hostBridge: _FakeHostBridge(),
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            manifestCache: InMemoryManifestCache(),
            screenCache: InMemoryScreenCache(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Pop to missing stack screen'));
      await tester.pumpAndSettle();

      expect(find.text('Pop to missing stack screen'), findsOneWidget);
      expect(find.text('Mini-program unavailable'), findsNothing);
    });
  });
}

class _FakeMiniProgramSource implements MiniProgramSource {
  _FakeMiniProgramSource({
    required this.manifest,
    this.screenJson = const <String, dynamic>{},
    Map<String, Map<String, dynamic>>? screenJsonById,
  }) : screenJsonById = screenJsonById ?? <String, Map<String, dynamic>>{};

  final MiniProgramManifest manifest;
  final Map<String, dynamic> screenJson;
  final Map<String, Map<String, dynamic>> screenJsonById;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return manifest;
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    final routedScreen = screenJsonById[screenId];
    if (routedScreen != null) {
      return routedScreen;
    }
    if (screenJson.isNotEmpty) {
      return screenJson;
    }

    throw MiniProgramSourceException(
      message:
          'Mini-program screen "$screenId" is not available for "$miniProgramId".',
      errorCode: MiniProgramErrorCodes.screenNotFound,
      details: <String, dynamic>{'screenId': screenId},
    );
  }
}

class _FailingManifestSource implements MiniProgramSource {
  const _FailingManifestSource({required this.exception});

  final MiniProgramSourceException exception;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) {
    throw exception;
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) => Future<Map<String, dynamic>>.error(exception);
}

class _FakeHostBridge implements HostBridge {
  final List<OpenNativeScreenActionPayload> openNativeScreenCalls = [];
  final List<CallSecureApiActionPayload> callSecureApiCalls = [];
  final List<TrackEventActionPayload> trackEventCalls = [];

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    openNativeScreenCalls.add(payload);
    return HostActionResult.success(
      actionName: ActionNames.openNativeScreen,
      data: const {'opened': true},
    );
  }

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    callSecureApiCalls.add(payload);
    return HostActionResult.success(
      actionName: ActionNames.callSecureApi,
      data: const {'secured': true},
    );
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    trackEventCalls.add(payload);
    return HostActionResult.success(
      actionName: ActionNames.trackEvent,
      data: const {'tracked': true},
    );
  }
}

class _RejectAllFeatureFlags implements FeatureFlagEvaluator {
  const _RejectAllFeatureFlags();

  @override
  bool isEnabled(FeatureFlagKey key) => false;
}

MiniProgramManifest _buildManifest({
  List<Capability> requiredCapabilities = const [Capability.auth],
  List<FeatureFlagKey> featureFlags = const [],
}) {
  return MiniProgramManifest(
    id: 'profile_center',
    version: '1.0.0',
    entry: 'profile/home',
    contractVersion: '1.0.0',
    sdkVersionRange: const SdkVersionRange(value: '>=1.0.0 <2.0.0'),
    requiredCapabilities: requiredCapabilities,
    featureFlags: featureFlags,
  );
}

const Map<String, dynamic> _helloScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'text',
      'data': 'Hello from profile center',
    },
  },
};

const Map<String, dynamic> _actionScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'elevatedButton',
      'onPressed': <String, dynamic>{
        'actionType': 'hostAction',
        'requestId': 'req-track-1',
        'action': 'trackEvent',
        'payload': <String, dynamic>{
          'name': 'profile_opened',
          'properties': <String, dynamic>{'source': 'widget_test'},
        },
      },
      'child': <String, dynamic>{'type': 'text', 'data': 'Track Event'},
    },
  },
};

const Map<String, dynamic> _secureApiScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'elevatedButton',
      'onPressed': <String, dynamic>{
        'actionType': 'hostAction',
        'requestId': 'req-secure-1',
        'action': 'callSecureApi',
        'payload': <String, dynamic>{
          'endpoint': 'feedback/submit',
          'method': 'POST',
          'body': <String, dynamic>{'source': 'feedback_form'},
        },
      },
      'child': <String, dynamic>{'type': 'text', 'data': 'Submit Securely'},
    },
  },
};

const Map<String, dynamic> _openDetailsScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'elevatedButton',
      'onPressed': <String, dynamic>{
        'actionType': 'miniProgramNavigation',
        'requestId': 'req-nav-open-1',
        'action': 'openMiniProgramScreen',
        'payload': <String, dynamic>{'screenId': 'profile/details'},
      },
      'child': <String, dynamic>{'type': 'text', 'data': 'Open details'},
    },
  },
};

const Map<String, dynamic> _replaceDetailsScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'elevatedButton',
      'onPressed': <String, dynamic>{
        'actionType': 'miniProgramNavigation',
        'requestId': 'req-nav-replace-1',
        'action': 'replaceMiniProgramScreen',
        'payload': <String, dynamic>{'screenId': 'profile/details'},
      },
      'child': <String, dynamic>{
        'type': 'text',
        'data': 'Replace with details',
      },
    },
  },
};

const Map<String, dynamic> _resetToDetailsScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'elevatedButton',
      'onPressed': <String, dynamic>{
        'actionType': 'miniProgramNavigation',
        'requestId': 'req-nav-reset-1',
        'action': 'resetMiniProgramStack',
        'payload': <String, dynamic>{'screenId': 'profile/details'},
      },
      'child': <String, dynamic>{'type': 'text', 'data': 'Reset to details'},
    },
  },
};

const Map<String, dynamic> _missingScreenActionJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'elevatedButton',
      'onPressed': <String, dynamic>{
        'actionType': 'miniProgramNavigation',
        'requestId': 'req-nav-missing-1',
        'action': 'openMiniProgramScreen',
        'payload': <String, dynamic>{'screenId': 'profile/missing'},
      },
      'child': <String, dynamic>{
        'type': 'text',
        'data': 'Open missing screen',
      },
    },
  },
};

const Map<String, dynamic> _detailsScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'column',
      'mainAxisAlignment': 'center',
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'text',
          'data': 'Portable details screen',
        },
        <String, dynamic>{
          'type': 'elevatedButton',
          'onPressed': <String, dynamic>{
            'actionType': 'miniProgramNavigation',
            'requestId': 'req-nav-pop-1',
            'action': 'popMiniProgramScreen',
            'payload': <String, dynamic>{},
          },
          'child': <String, dynamic>{
            'type': 'text',
            'data': 'Back to first screen',
          },
        },
      ],
    },
  },
};

const Map<String, dynamic> _openConfirmScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'elevatedButton',
      'onPressed': <String, dynamic>{
        'actionType': 'miniProgramNavigation',
        'requestId': 'req-nav-open-confirm-1',
        'action': 'openMiniProgramScreen',
        'payload': <String, dynamic>{'screenId': 'profile/confirm'},
      },
      'child': <String, dynamic>{
        'type': 'text',
        'data': 'Open confirm screen',
      },
    },
  },
};

const Map<String, dynamic> _popToRootScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'column',
      'mainAxisAlignment': 'center',
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'text',
          'data': 'Portable confirm screen',
        },
        <String, dynamic>{
          'type': 'elevatedButton',
          'onPressed': <String, dynamic>{
            'actionType': 'miniProgramNavigation',
            'requestId': 'req-nav-pop-root-1',
            'action': 'popToMiniProgramRoot',
            'payload': <String, dynamic>{},
          },
          'child': <String, dynamic>{
            'type': 'text',
            'data': 'Pop to root',
          },
        },
      ],
    },
  },
};

const Map<String, dynamic> _popToDetailsScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'column',
      'mainAxisAlignment': 'center',
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'text',
          'data': 'Portable confirm screen',
        },
        <String, dynamic>{
          'type': 'elevatedButton',
          'onPressed': <String, dynamic>{
            'actionType': 'miniProgramNavigation',
            'requestId': 'req-nav-pop-details-1',
            'action': 'popToMiniProgramScreen',
            'payload': <String, dynamic>{'screenId': 'profile/details'},
          },
          'child': <String, dynamic>{
            'type': 'text',
            'data': 'Pop to details',
          },
        },
      ],
    },
  },
};

const Map<String, dynamic> _popToMissingStackScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{
      'type': 'elevatedButton',
      'onPressed': <String, dynamic>{
        'actionType': 'miniProgramNavigation',
        'requestId': 'req-nav-pop-missing-stack-1',
        'action': 'popToMiniProgramScreen',
        'payload': <String, dynamic>{'screenId': 'profile/confirm'},
      },
      'child': <String, dynamic>{
        'type': 'text',
        'data': 'Pop to missing stack screen',
      },
    },
  },
};
