import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:mp_only_host/phone_ai/phone_ai_model.dart';
import 'package:mp_only_host/phone_ai/phone_ai_runner.dart';
import 'package:mp_only_host/phone_ai/host_ai_bubble.dart';

void main() {
  testWidgets(
    'two goals edit real controls then scroll the catalog in the same session',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.reset);
      final controller = MiniProgramInteractionController();
      var step = 0;
      final model = _Model((view) {
        final decision = switch (step++) {
          0 => {
            'action': 'enterText',
            'targetId': _target(view, 'Search products', 'enterText'),
            'text': 'Green tea',
          },
          1 => {'action': 'tap', 'targetId': _target(view, 'Delivery')},
          2 => {'action': 'tap', 'targetId': _target(view, 'Pickup')},
          3 => {
            'action': 'tap',
            'targetId': _target(view, 'Use a reusable cup'),
          },
          4 => {'action': 'tap', 'targetId': _target(view, 'Pickup date')},
          5 => {'action': 'tap', 'targetId': _target(view, RegExp(r'\b28\b'))},
          6 => {'action': 'tap', 'targetId': _target(view, 'OK')},
          7 => {
            'action': 'tap',
            'targetId': _target(view, 'Review preferences'),
          },
          _ => {
            'action': 'done',
            'message':
                'The preference review shows the selected tea, pickup, cup and date.',
          },
        };
        return PhoneAiReply(decision: decision);
      });
      await _mount(tester, controller);
      final catalogModel = _Model(_catalogDecision);
      var factories = 0;
      final runner = _runner(
        controller,
        model,
        modelFactory: () => factories++ == 0 ? model : catalogModel,
      );
      try {
        await _drive(tester, runner.start('Prepare the tea preferences'));
        expect(
          runner.outcome,
          PhoneAiOutcome.completed,
          reason:
              '${runner.status}: ${runner.message}. ${model.failure}. ${runner.history}\n${jsonEncode(model.views.last)}',
        );
        final observed = await _drive(tester, controller.observe());
        final text = observed.nodes
            .map((node) => '${node.label} ${node.value ?? ''}')
            .join('\n');
        expect(text, contains('Preference review'));
        expect(text, contains('Green tea'));
        expect(text, contains('2026-10-28'));
        expect(text, contains('pickup'));
        expect(text, contains('true'));
        expect(text, isNot(contains('Host assistant')));
        final session = observed.sessionId;
        await _drive(
          tester,
          runner.start('Open the details of catalog item 18'),
        );
        expect(
          runner.outcome,
          PhoneAiOutcome.completed,
          reason:
              '${runner.status}: ${runner.message}. ${catalogModel.failure}',
        );
        expect(catalogModel.views.first['sessionId'], session);
        expect(
          jsonEncode(catalogModel.views.first),
          contains('Preference review'),
        );
        expect(runner.history.first, startsWith('tap Close review'));
        expect(
          runner.history.any((entry) => entry.startsWith('enterText')),
          isFalse,
        );
        expect(
          jsonEncode(catalogModel.views.last),
          contains('Catalog item 18 details'),
        );
        await tester.tap(find.text('Close details'));
        await tester.pumpAndSettle();
        expect(find.text('Back to preferences').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Back to preferences'));
        await tester.pumpAndSettle();
        expect(find.text('Tea preferences'), findsOneWidget);
        final restored = await _drive(tester, controller.observe());
        expect(restored.sessionId, session);
        expect(jsonEncode(restored.toJson()), contains('Green tea'));
        expect(jsonEncode(restored.toJson()), contains('10/28/2026'));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        runner.dispose();
        controller.dispose();
      }
    },
  );

  testWidgets(
    'the host runner finds an offscreen catalog item by scrolling current UI',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 700);
      addTearDown(tester.view.reset);
      final controller = MiniProgramInteractionController();
      final model = _Model((view) {
        final nodes = (view['nodes'] as List).cast<Map>();
        if (nodes.any(
          (node) => '${node['label']}'.contains('Catalog item 18 details'),
        )) {
          return PhoneAiReply(
            decision: {
              'action': 'done',
              'message': 'Catalog item 18 details are open.',
            },
          );
        }
        for (final label in ['Browse catalog', 'Open item 18']) {
          final available = nodes.where(
            (node) =>
                '${node['label']}'.split('\n').first == label &&
                (node['actions'] as List? ?? const []).contains('tap'),
          );
          if (available.isNotEmpty) {
            return PhoneAiReply(
              decision: {'action': 'tap', 'targetId': available.first['id']},
            );
          }
        }
        final scroll = nodes.firstWhere(
          (node) => (node['actions'] as List? ?? const []).contains('scrollUp'),
        );
        return PhoneAiReply(
          decision: {'action': 'scrollUp', 'targetId': scroll['id']},
        );
      });
      await _mount(tester, controller);
      final runner = _runner(controller, model);
      try {
        await _drive(
          tester,
          runner.start('Open the details of catalog item 18'),
        );
        expect(
          runner.outcome,
          PhoneAiOutcome.completed,
          reason:
              '${runner.status}: ${runner.message}. ${model.failure}. ${runner.history}\n${jsonEncode(model.views.last)}',
        );
        expect(
          runner.history.any((entry) => entry.startsWith('scrollUp')),
          isTrue,
        );
        expect(model.views.length, lessThan(16));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        runner.dispose();
        controller.dispose();
      }
    },
  );
}

PhoneAiRunner _runner(
  MiniProgramInteractionController controller,
  PhoneAiModel model, {
  PhoneAiModelFactory? modelFactory,
}) => PhoneAiRunner(
  appId: 'mp_ai_controls_demo',
  isForeground: () => true,
  modelFactory: modelFactory ?? () => model,
  limits: const PhoneAiLimits(
    observationInterval: Duration.zero,
    actionInterval: Duration.zero,
  ),
  dispatch: controller.handleRequest,
);

PhoneAiReply _catalogDecision(Map<String, dynamic> view) {
  final nodes = (view['nodes'] as List).cast<Map>();
  if (nodes.any(
    (node) => '${node['label']}'.contains('Catalog item 18 details'),
  )) {
    return PhoneAiReply(
      decision: {
        'action': 'done',
        'message': 'Catalog item 18 details are open.',
      },
    );
  }
  for (final label in ['Close review', 'Browse catalog', 'Open item 18']) {
    final available = nodes.where(
      (node) =>
          '${node['label']}'.split('\n').first == label &&
          (node['actions'] as List? ?? const []).contains('tap'),
    );
    if (available.isNotEmpty) {
      return PhoneAiReply(
        decision: {'action': 'tap', 'targetId': available.first['id']},
      );
    }
  }
  final scroll = nodes.firstWhere(
    (node) => (node['actions'] as List? ?? const []).contains('scrollUp'),
  );
  return PhoneAiReply(
    decision: {'action': 'scrollUp', 'targetId': scroll['id']},
  );
}

Future<void> _mount(
  WidgetTester tester,
  MiniProgramInteractionController controller,
) async {
  final files = <String, Map<String, dynamic>>{};
  await tester.runAsync(() async {
    for (final path in [
      'manifest.json',
      'screens/home.json',
      'screens/catalog.json',
    ]) {
      files[path] =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/mini_programs/mp_ai_controls_demo/$path',
                ),
              )
              as Map<String, dynamic>;
    }
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: (_, child) => HostAiBubble(
        status: 'Host-only model configuration',
        style: const HostAiBubbleStyle(label: 'Host assistant'),
        onPressed: () {},
        child: child!,
      ),
      home: Scaffold(
        body: MiniProgramHost(
          miniProgramId: 'mp_ai_controls_demo',
          sdkVersion: '1.0.0',
          source: _Source(files),
          hostBridge: _Bridge(),
          capabilityRegistry: CapabilityRegistry(const []),
          interactionController: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _target(
  Map<String, dynamic> view,
  Pattern label, [
  String action = 'tap',
]) =>
    (view['nodes'] as List).cast<Map>().firstWhere(
          (node) =>
              '${node['label'] ?? ''}'.contains(label) &&
              (node['actions'] as List? ?? const []).contains(action),
          orElse: () => throw StateError(
            'Missing $label for $action in ${view['screenId']}',
          ),
        )['id']
        as String;

Future<T> _drive<T>(WidgetTester tester, Future<T> work) async {
  var done = false;
  final tracked = work.whenComplete(() => done = true);
  for (var frame = 0; frame < 500 && !done; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(
    done,
    isTrue,
    reason: 'The foreground flow did not settle within 500 frames.',
  );
  return tracked;
}

class _Model implements PhoneAiModel {
  _Model(this.reply);
  final PhoneAiReply Function(Map<String, dynamic>) reply;
  final views = <Map<String, dynamic>>[];
  Object? failure;
  @override
  Future<PhoneAiReply> decide({
    required String goal,
    required Map<String, dynamic> snapshot,
    required List<String> progress,
  }) async {
    views.add(snapshot);
    try {
      return reply(snapshot);
    } on Object catch (error) {
      failure = error;
      rethrow;
    }
  }

  @override
  void close() {}
}

class _Source implements MiniProgramSource {
  _Source(this.files);
  final Map<String, Map<String, dynamic>> files;
  Future<Map<String, dynamic>> _load(String path) async => files[path]!;
  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async =>
      MiniProgramManifest.fromJson(await _load('manifest.json'));
  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) => _load('screens/$screenId.json');
}

class _Bridge implements HostBridge {
  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async => throw UnimplementedError();
  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async => throw UnimplementedError();
  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async =>
      HostActionResult.success();
}
