import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_only_host/phone_ai/host_ai_catalog.dart';
import 'package:mp_only_host/phone_ai/host_ai_coordinator.dart';
import 'package:mp_only_host/phone_ai/phone_ai_model.dart';
import 'package:mp_only_host/phone_ai/phone_ai_runner.dart';

const _owner = MethodChannel('test/host_ai_owner');
const _client = MethodChannel('test/host_ai_client');
const _fast = PhoneAiLimits(
  observationInterval: Duration.zero,
  actionInterval: Duration.zero,
);

void main() {
  testWidgets(
    'one goal opens a native task from the host and continues there',
    (tester) async {
      var focused = HostAiCatalog.appId;
      var handoffObservations = 0;
      final opened = <String>[];
      final catalog = HostAiCatalog(
        titles: const {'food': 'Food ordering'},
        openMiniProgram: (id) async {
          opened.add(id);
        },
      );
      await tester.pumpWidget(_catalog(catalog));
      var revision = 1;
      var loadingReads = 0;
      var added = false;
      var factories = 0;
      final views = <String>[];
      final model = _Model((snapshot) async {
        views.add(snapshot['appId'] as String);
        if (snapshot['appId'] == HostAiCatalog.appId) {
          return PhoneAiReply(decision: {'action': 'tap', 'targetId': 'food'});
        }
        return added
            ? PhoneAiReply(
                decision: {
                  'action': 'done',
                  'message': 'Order review shows two portions.',
                },
              )
            : PhoneAiReply(decision: {'action': 'tap', 'targetId': 'add'});
      });
      final coordinator = HostAiCoordinator(
        catalog: catalog,
        channel: _owner,
        limits: _fast,
        modelFactory: () {
          factories++;
          return model;
        },
        miniProgramDispatch: (request) async {
          if (request['method'] == 'interact') {
            added = true;
            revision++;
            return {'status': 'completed'};
          }
          if (loadingReads++ < 2) return {'status': 'unavailable', 'appId': ''};
          return _food(revision: revision, added: added);
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_owner, (
        call,
      ) async {
        if (call.method == 'foreground') {
          if (opened.isNotEmpty && ++handoffObservations >= 3) focused = 'food';
          return {'appId': focused};
        }
        return null;
      });
      await coordinator.bind();
      await tester.runAsync(
        () => coordinator.runner.start(
          'Open food ordering and prepare two portions.',
        ),
      );
      expect(coordinator.runner.outcome, PhoneAiOutcome.completed);
      expect(opened, ['food']);
      expect(views, [HostAiCatalog.appId, 'food', 'food']);
      expect(factories, 1);
      expect(handoffObservations, greaterThanOrEqualTo(3));
      expect(loadingReads, greaterThan(2));
      expect(model.goals.toSet(), {
        'Open food ordering and prepare two portions.',
      });
      expect(coordinator.runner.history.first, contains('Open Food ordering'));
      expect(model.closed, isTrue);
      coordinator.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      catalog.dispose();
    },
  );

  testWidgets('task Stop cancels the host model and rejects its late reply', (
    tester,
  ) async {
    final catalog = HostAiCatalog(
      titles: const {},
      openMiniProgram: (_) async {},
    );
    final reply = Completer<PhoneAiReply>();
    final model = _Model((_) => reply.future);
    var operations = 0;
    var sequence = 0;
    Map<String, dynamic>? published;
    var focused = 'food';
    final coordinator = HostAiCoordinator(
      catalog: catalog,
      channel: _owner,
      limits: _fast,
      modelFactory: () => model,
      miniProgramDispatch: (request) async {
        if (request['method'] == 'interact') operations++;
        return _food();
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_owner, (
      call,
    ) async {
      if (call.method == 'foreground') return {'appId': focused};
      if (call.method == 'publish') {
        published = {'sequence': ++sequence, 'state': call.arguments};
        await _deliver(tester, _client, MethodCall('state', published));
      }
      return null;
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_client, (
      call,
    ) async {
      if (call.method == 'attach') return published;
      if (call.method == 'command') {
        return _deliver(
          tester,
          _owner,
          MethodCall('command', {'appId': 'food', 'command': call.arguments}),
        );
      }
      return null;
    });
    final client = HostAiSessionClient(appId: 'food', channel: _client);
    await tester.runAsync(() async {
      await client.bind();
      await coordinator.bind();
      await client.start('Add noodles.');
      for (var attempt = 0; attempt < 20 && model.calls == 0; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(
        model.calls,
        1,
        reason:
            '${coordinator.runner.status}: ${coordinator.runner.message}; client: ${client.status}',
      );
      expect(client.running, isTrue);
      client.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(coordinator.runner.outcome, PhoneAiOutcome.cancelled);
      expect(client.outcome, PhoneAiOutcome.cancelled);
      await _deliver(
        tester,
        _client,
        MethodCall('state', {
          'sequence': sequence - 1,
          'state': {'running': true, 'outcome': 'running'},
        }),
      );
      expect(client.outcome, PhoneAiOutcome.cancelled);
      expect(client.running, isFalse);
      expect(model.closed, isTrue);
      expect(client.draft, 'Add noodles.');
      reply.complete(
        PhoneAiReply(decision: {'action': 'tap', 'targetId': 'add'}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(operations, 0);
      expect(client.outcome, PhoneAiOutcome.cancelled);
      // A different foreground task cannot start a command stamped by this view.
      focused = 'other';
      await client.start('Hidden action');
      expect(coordinator.runner.running, isFalse);
    });
    client.dispose();
    coordinator.dispose();
    catalog.dispose();
    await tester.pump();
  });

  testWidgets(
    'host catalog excludes clipped controls and rejects stale commands',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final opened = <String>[];
      final catalog = HostAiCatalog(
        titles: {for (var i = 0; i < 12; i++) 'app$i': 'Mini app $i'},
        openMiniProgram: (id) async => opened.add(id),
      );
      await tester.pumpWidget(_catalog(catalog));
      final view = catalog.observe();
      final nodes = view['nodes'] as List;
      expect(nodes.any((node) => node['id'] == 'app0'), isTrue);
      expect(nodes.any((node) => node['id'] == 'app11'), isFalse);
      final request = {
        'method': 'interact',
        'request': {
          'sessionId': view['sessionId'],
          'revision': view['revision'],
          'action': 'tap',
          'targetId': 'app0',
        },
      };
      catalog.invalidate();
      expect((await catalog.dispatch(request))['code'], 'stale_view');
      expect(opened, isEmpty);
      // A host popup covers the catalog; no underlying host action is observed.
      final context = catalog.viewportKey.currentContext!;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(title: Text('Host dialog')),
        ),
      );
      await tester.pumpAndSettle();
      expect(catalog.observe()['nodes'], isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      catalog.dispose();
    },
  );

  testWidgets(
    'leaving the app pauses shared work, internal task handoff does not',
    (tester) async {
      final catalog = HostAiCatalog(
        titles: const {},
        openMiniProgram: (_) async {},
      );
      final model = _Model((_) => Completer<PhoneAiReply>().future);
      final coordinator = HostAiCoordinator(
        catalog: catalog,
        channel: _owner,
        limits: _fast,
        modelFactory: () => model,
        miniProgramDispatch: (_) async => _food(),
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_owner, (
        call,
      ) async {
        if (call.method == 'foreground') return {'appId': 'food'};
        return null;
      });
      await coordinator.bind();
      unawaited(coordinator.runner.start('Prepare food'));
      await tester.pump();
      await _deliver(tester, _owner, const MethodCall('foregroundChanged'));
      await tester.pump(const Duration(milliseconds: 300));
      await _deliver(
        tester,
        _owner,
        const MethodCall('foregroundChanged', {'appId': 'food'}),
      );
      await tester.pump(const Duration(milliseconds: 900));
      expect(coordinator.runner.running, isTrue);
      await _deliver(tester, _owner, const MethodCall('foregroundChanged'));
      await tester.pump(const Duration(milliseconds: 900));
      expect(coordinator.runner.outcome, PhoneAiOutcome.stopped);
      expect(model.closed, isTrue);
      coordinator.dispose();
      catalog.dispose();
      await tester.pump();
    },
  );
}

Widget _catalog(HostAiCatalog catalog) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      key: catalog.viewportKey,
      height: 180,
      child: SingleChildScrollView(
        controller: catalog.scrollController,
        child: Column(
          children: [
            for (final entry in catalog.titles.entries)
              SizedBox(
                height: 56,
                child: TextButton(
                  key: catalog.buttonKeys[entry.key],
                  onPressed: () {},
                  child: Text('Open ${entry.value}'),
                ),
              ),
          ],
        ),
      ),
    ),
  ),
);

Map<String, dynamic> _food({int revision = 1, bool added = false}) => {
  'appId': 'food',
  'sessionId': 'food-session',
  'screenId': 'menu',
  'revision': revision,
  'status': 'ready',
  'canGoBack': false,
  'nodes': [
    {
      'id': 'add',
      'role': 'button',
      'label': added ? 'Order review shows two portions' : 'Add two portions',
      'actions': ['tap'],
    },
  ],
};

Future<dynamic> _deliver(
  WidgetTester tester,
  MethodChannel channel,
  MethodCall call,
) async {
  const codec = StandardMethodCodec();
  final response = Completer<ByteData?>();
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    channel.name,
    codec.encodeMethodCall(call),
    response.complete,
  );
  final bytes = await response.future;
  return bytes == null ? null : codec.decodeEnvelope(bytes);
}

class _Model implements PhoneAiModel {
  _Model(this.reply);
  final Future<PhoneAiReply> Function(Map<String, dynamic>) reply;
  final goals = <String>[];
  int calls = 0;
  bool closed = false;
  @override
  Future<PhoneAiReply> decide({
    required String goal,
    required Map<String, dynamic> snapshot,
    required List<String> progress,
  }) {
    calls++;
    goals.add(goal);
    return reply(snapshot);
  }

  @override
  void close() => closed = true;
}
