import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:mp_only_host/main.dart' as app;

const _tasks = MethodChannel(
  'dev.miniprogram.mp_only_host/mini_program_window',
);
const _goal =
    'Open the food menu, add exactly two portions of vegetarian noodles, '
    'open the cart, enter the delivery note "No onions", and open Order review. '
    'Finish only when the review shows two portions and that note. Do not submit an order or payment.';
var _requestId = 0;

// flutter drive compiles this file as the root library. Preserve the production
// Activity entrypoint for additional engines without changing native startup.
@pragma('vm:entry-point')
Future<void> miniProgramMain() => app.miniProgramMain();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'embedded screen uses the same foreground interaction controller',
    (tester) async {
      final controller = MiniProgramInteractionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniProgramHost(
              miniProgramId: 'mp_ai_food_demo',
              sdkVersion: '1.0.0',
              source: _FixtureSource(),
              hostBridge: _Bridge(),
              capabilityRegistry: CapabilityRegistry(const []),
              interactionController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Map snapshot = (await controller.observe()).toJson();
      expect(snapshot['screenId'], 'home');
      snapshot = await _tap(controller.handleRequest, snapshot, 'Browse menu');
      expect(snapshot['screenId'], 'menu');
      snapshot = await _tap(controller.handleRequest, snapshot, 'Add noodles');
      expect(_text(snapshot), contains('Cart quantity: 1'));
      final stale = await controller.handleRequest({
        'method': 'interact',
        'request': {
          'requestId': 'stale-test',
          'sessionId': snapshot['sessionId'],
          'revision': 1,
          'targetId': _target(snapshot, 'Add noodles')['id'],
          'action': 'tap',
        },
      });
      expect(stale['code'], 'stale_view');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'separate Android tasks preserve drafts and route only to the focused mini-program',
    (tester) async {
      app.main();
      await tester.pumpAndSettle();
      final relay = MiniProgramInteractionChannel();
      await _open('mp_ai_food_demo', 'AI Food Demo');
      var snapshot = await _ready(relay);
      final sessionId = snapshot['sessionId'];
      expect(snapshot['screenId'], 'home');
      const server = String.fromEnvironment('MINI_PROGRAM_AI_TEST_SERVER');
      if (server.isNotEmpty) {
        snapshot = await _liveFlow(relay, snapshot, server);
      } else {
        snapshot = await _tap(relay.dispatch, snapshot, 'Browse menu');
        snapshot = await _tap(relay.dispatch, snapshot, 'Add noodles');
        snapshot = await _tap(relay.dispatch, snapshot, 'Add noodles');
        snapshot = await _tap(relay.dispatch, snapshot, 'View cart');
        snapshot = await _enterNote(relay.dispatch, snapshot);
        snapshot = await _tap(relay.dispatch, snapshot, 'Review order');
      }
      expect(_text(snapshot), contains('Order review'));
      expect(_text(snapshot), contains('2 portions'));
      expect(_text(snapshot), contains('No onions'));
      snapshot = await _tap(relay.dispatch, snapshot, 'Close review');
      expect(snapshot['screenId'], 'cart');
      final oldRequest = _command(
        snapshot,
        _target(snapshot, 'Review order'),
        'tap',
      );

      // Switch to a second real mini-program task; the old session has no authority.
      await _open('mp_orders', 'Mp Orders');
      final other = await _ready(relay);
      expect(other['appId'], 'mp_orders');
      expect(other['sessionId'], isNot(sessionId));
      final wrongOwner = await relay.dispatch({
        'method': 'interact',
        'request': oldRequest,
      });
      expect(wrongOwner['code'], 'foreground_required');
      await _open('mp_ai_food_demo', 'AI Food Demo');
      snapshot = await _ready(relay);
      expect(snapshot['sessionId'], sessionId);
      expect(snapshot['screenId'], 'cart');
      expect(_text(snapshot), contains('No onions'));
      expect(_text(snapshot), contains('2 portions'));

      // Back dismisses the keyboard, then inner screens, then returns to host.
      for (var i = 0; i < 5; i++) {
        final result = await relay.dispatch({
          'method': 'interact',
          'request': _command(snapshot, null, 'back'),
        });
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final observed = await relay.dispatch({'method': 'observe'});
        if (observed['status'] == 'unavailable') break;
        snapshot = result['snapshot'] as Map;
        snapshot = observed;
      }
      expect(
        (await relay.dispatch({'method': 'observe'}))['code'],
        'foreground_required',
      );
      await _open('mp_ai_food_demo', 'AI Food Demo');
      snapshot = await _ready(relay);
      expect(snapshot['sessionId'], sessionId);
      expect(snapshot['screenId'], 'home');
      snapshot = await _tap(relay.dispatch, snapshot, 'Browse menu');
      snapshot = await _tap(relay.dispatch, snapshot, 'View cart');
      expect(_text(snapshot), contains('No onions'));
      expect(_text(snapshot), contains('2 portions'));
      // Fixture-only diagnostic; no credentials or personal content.
      // ignore: avoid_print
      print(
        'ANDROID_FOREGROUND_INTERACTION_PASS: embedded + two tasks + retained cart',
      );
    },
  );
}

typedef _Dispatch =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);

Future<void> _open(String appId, String title) => _tasks.invokeMethod<void>(
  'openMiniProgram',
  {'appId': appId, 'title': title},
);

Future<Map> _ready(MiniProgramInteractionChannel relay) =>
    _observeReady(relay.dispatch);

Future<Map> _observeReady(_Dispatch dispatch) async {
  Map snapshot = const {};
  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    snapshot = await dispatch({'method': 'observe'});
    if (snapshot['status'] == 'ready') return snapshot;
  }
  throw StateError('Foreground screen not ready: $snapshot');
}

Map _target(Map snapshot, String label) =>
    (snapshot['nodes'] as List).cast<Map>().firstWhere(
      (n) =>
          (n['label'] ?? '').toString().contains(label) &&
          (n['actions'] as List? ?? []).contains('tap'),
      orElse: () => throw StateError('Missing $label in $snapshot'),
    );

Map<String, dynamic> _command(
  Map snapshot,
  Map? target,
  String action, {
  String? text,
}) => {
  'requestId': 'emulator-${++_requestId}',
  'sessionId': snapshot['sessionId'],
  'revision': snapshot['revision'],
  'action': action,
  if (target != null) 'targetId': target['id'],
  'text': ?text,
};

Future<Map> _tap(_Dispatch dispatch, Map snapshot, String label) async {
  snapshot = await _observeReady(dispatch);
  final result = await dispatch({
    'method': 'interact',
    'request': _command(snapshot, _target(snapshot, label), 'tap'),
  });
  expect(result['status'], anyOf('completed', 'pending'), reason: '$result');
  // A slow frame or opening panel may still be pending. Observe its outcome;
  // never repeat an accepted tap just because rendering has not finished.
  return result['snapshot']['status'] == 'ready'
      ? result['snapshot'] as Map
      : _observeReady(dispatch);
}

Future<Map> _enterNote(_Dispatch dispatch, Map snapshot) async {
  snapshot = await _observeReady(dispatch);
  final field = (snapshot['nodes'] as List).cast<Map>().firstWhere(
    (n) => n['role'] == 'textField',
  );
  final result = await dispatch({
    'method': 'interact',
    'request': _command(snapshot, field, 'enterText', text: 'No onions'),
  });
  expect(result['status'], anyOf('completed', 'pending'), reason: '$result');
  return result['snapshot']['status'] == 'ready'
      ? result['snapshot'] as Map
      : _observeReady(dispatch);
}

String _text(Map snapshot) => (snapshot['nodes'] as List? ?? [])
    .cast<Map>()
    .map((n) => '${n['label'] ?? ''} ${n['value'] ?? ''}')
    .join('\n');

Future<Map> _liveFlow(
  MiniProgramInteractionChannel relay,
  Map snapshot,
  String server,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final progress = <String>[];
  try {
    for (var step = 0; step < 16; step++) {
      final request = await client.postUrl(Uri.parse('$server/decide'));
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${const String.fromEnvironment('MINI_PROGRAM_AI_TEST_TOKEN')}',
      );
      final payload = utf8.encode(
        jsonEncode({'goal': _goal, 'snapshot': snapshot, 'progress': progress}),
      );
      request.contentLength = payload.length;
      request.add(payload);
      final response = await request.close().timeout(
        const Duration(seconds: 100),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw StateError('AI test server failed: HTTP ${response.statusCode}');
      }
      final decision = jsonDecode(body) as Map;
      if (decision['action'] == 'done') return await _ready(relay);
      final nodes = (snapshot['nodes'] as List).cast<Map>();
      final action = decision['action'] as String;
      final targetId = decision['targetId'];
      final target = action == 'back'
          ? null
          : nodes.firstWhere((n) => n['id'] == targetId);
      final result = await relay.dispatch({
        'method': 'interact',
        'request': _command(
          snapshot,
          target,
          action,
          text: decision['text'] as String?,
        ),
      });
      progress.add('$action ${target?['label'] ?? ''}: ${result['status']}');
      // Fixture diagnostics contain no credentials or user data.
      // ignore: avoid_print
      print('AI_UI_STEP: $action ${result['status']} ${result['code'] ?? ''}');
      expect(progress.length, lessThanOrEqualTo(16));
      if (result['snapshot'] is Map) snapshot = result['snapshot'] as Map;
      if (result['snapshot'] is! Map ||
          snapshot['status'] != 'ready' ||
          result['code'] == 'stale_view') {
        snapshot = await _ready(relay);
      }
    }
    throw StateError('AI did not finish within 16 decisions.');
  } finally {
    client.close(force: true);
  }
}

class _FixtureSource implements MiniProgramSource {
  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async =>
      MiniProgramManifest.fromJson(
        jsonDecode(
              await rootBundle.loadString(
                'assets/mini_programs/mp_ai_food_demo/manifest.json',
              ),
            )
            as Map<String, dynamic>,
      );
  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async =>
      jsonDecode(
            await rootBundle.loadString(
              'assets/mini_programs/mp_ai_food_demo/screens/$screenId.json',
            ),
          )
          as Map<String, dynamic>;
}

class _Bridge implements HostBridge {
  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async => HostActionResult.success();
  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async => HostActionResult.success();
  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async =>
      HostActionResult.success();
}
