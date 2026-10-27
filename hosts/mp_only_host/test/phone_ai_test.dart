import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_only_host/phone_ai/phone_ai_model.dart';
import 'package:mp_only_host/phone_ai/phone_ai_runner.dart';
import 'package:mp_only_host/phone_ai/phone_ai_test_workspace.dart';

Map<String, dynamic> _snapshot({int revision = 1}) => {
  'appId': 'food',
  'sessionId': 'session-one',
  'screenId': 'home',
  'revision': revision,
  'status': 'ready',
  'canGoBack': false,
  'nodes': [
    {
      'id': 'n1',
      'role': 'button',
      'label': 'Add noodles',
      'actions': ['tap'],
    },
    {'id': 'n2', 'role': 'protectedField', 'actions': <String>[]},
  ],
};

Map<String, dynamic> _response(Map<String, dynamic> decision) => {
  'choices': [
    {
      'message': {'content': jsonEncode(decision)},
    },
  ],
  'usage': {'total_tokens': 123, 'cost': 0.001},
};

void main() {
  test('validates model output against the observed controls', () {
    final reply = PhoneAiReply.parse(
      _response({'action': 'tap', 'targetId': 'n1'}),
      _snapshot(),
    );
    expect(reply.decision['targetId'], 'n1');
    expect(reply.tokens, 123);
    expect(reply.costUsd, 0.001);
    for (final decision in <Map<String, dynamic>>[
      {'action': 'tap', 'targetId': 'n2'},
      {'action': 'tap', 'targetId': 'missing'},
      {'action': 'back'},
      {'action': 'state.set', 'targetId': 'n1'},
      {'action': 'done', 'text': 'unexpected'},
      {'action': 'tap', 'targetId': 'n1', 'url': 'https://other.example'},
    ]) {
      expect(
        () => PhoneAiReply.parse(_response(decision), _snapshot()),
        throwsFormatException,
      );
    }
  });

  test('applies one decision, observes again, and reports usage', () async {
    var revision = 1;
    final requests = <Map<String, dynamic>>[];
    final model = _Model(
      (call) async => PhoneAiReply(
        decision: call == 1
            ? {'action': 'tap', 'targetId': 'n1'}
            : {
                'action': 'done',
                'message': 'The goal is visible on the screen.',
              },
        tokens: 100,
        costUsd: 0.001,
      ),
    );
    final runner = PhoneAiRunner(
      appId: 'food',
      isForeground: () => true,
      modelFactory: () => model,
      dispatch: (request) async {
        requests.add(request);
        if (request['method'] == 'observe') {
          return _snapshot(revision: revision);
        }
        expect(request['request']['revision'], 1);
        revision++;
        return {'status': 'completed'};
      },
    );
    await runner.start('Add noodles');
    expect(requests.where((r) => r['method'] == 'interact'), hasLength(1));
    expect(model.snapshots.map((s) => s['revision']), [1, 2]);
    expect(runner.outcome, PhoneAiOutcome.completed);
    expect(runner.tokens, 200);
    expect(runner.costUsd, 0.002);
    expect(runner.running, isFalse);
    expect(model.closed, isTrue);
    runner.dispose();
  });

  for (final stopKind in ['manual stop', 'background', 'disposal']) {
    test('does not apply a delayed model reply after $stopKind', () async {
      var foreground = true;
      final response = Completer<PhoneAiReply>();
      final started = Completer<void>();
      final model = _Model((_) {
        started.complete();
        return response.future;
      });
      var interactions = 0;
      final runner = PhoneAiRunner(
        appId: 'food',
        isForeground: () => foreground,
        modelFactory: () => model,
        dispatch: (request) async {
          if (request['method'] == 'interact') interactions++;
          return _snapshot();
        },
      );
      final run = runner.start('Add noodles');
      await started.future;
      switch (stopKind) {
        case 'manual stop':
          runner.stop();
        case 'background':
          foreground = false;
        case 'disposal':
          runner.dispose();
      }
      response.complete(
        PhoneAiReply(decision: {'action': 'tap', 'targetId': 'n1'}),
      );
      await run;
      expect(interactions, 0);
      expect(model.closed, isTrue);
      if (stopKind != 'disposal') runner.dispose();
    });
  }

  test(
    'waits for keyboard or layout revisions to settle before asking the model',
    () async {
      var observations = 0;
      final model = _Model(
        (_) async => PhoneAiReply(
          decision: {
            'action': 'done',
            'message': 'The goal is visible on the screen.',
          },
        ),
      );
      final runner = PhoneAiRunner(
        appId: 'food',
        isForeground: () => true,
        modelFactory: () => model,
        dispatch: (request) async {
          expect(request['method'], 'observe');
          observations++;
          return _snapshot(revision: observations == 1 ? 1 : 2);
        },
      );
      await runner.start('Review the cart');
      expect(model.snapshots.single['revision'], 2);
      expect(observations, greaterThanOrEqualTo(3));
      expect(runner.outcome, PhoneAiOutcome.completed);
      runner.dispose();
    },
  );

  test('never replays stale, failed, or uncertain interactions', () async {
    for (final status in ['rejected', 'failed', 'unknown', 'interrupted']) {
      var interactions = 0;
      final model = _Model(
        (_) async =>
            PhoneAiReply(decision: {'action': 'tap', 'targetId': 'n1'}),
      );
      final runner = PhoneAiRunner(
        appId: 'food',
        isForeground: () => true,
        modelFactory: () => model,
        dispatch: (request) async {
          if (request['method'] == 'observe') return _snapshot();
          interactions++;
          return {'status': status};
        },
      );
      await runner.start('Add noodles');
      expect(interactions, 1);
      expect(model.calls, 1);
      expect(runner.message, contains('interrupted'));
      runner.dispose();
    }
  });

  test(
    'provider errors produce safe status without leaking response details',
    () async {
      final runner = PhoneAiRunner(
        appId: 'food',
        dispatch: (_) async => _snapshot(),
        isForeground: () => true,
        modelFactory: () =>
            _Model((_) async => throw const PhoneAiHttpFailure(402)),
      );
      await runner.start('Add noodles');
      expect(runner.status, contains('credit limit'));
      expect(runner.running, isFalse);
      runner.dispose();
    },
  );

  testWidgets(
    'progress keeps the mini-program fixed and Stop cancels its reply',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final navigator = GlobalKey<NavigatorState>();
      final response = Completer<PhoneAiReply>();
      var interactions = 0;
      final model = _Model((_) => response.future);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PhoneAiTestWorkspace(
            appId: 'food',
            dispatch: (request) async {
              if (request['method'] == 'interact') interactions++;
              return _snapshot();
            },
            navigatorKey: navigator,
            modelFactory: () => model,
            child: child!,
          ),
          home: const Scaffold(body: Text('Mini-program body')),
        ),
      );
      final before = tester.getTopLeft(find.text('Mini-program body'));
      await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start AI'));
      await tester.tap(find.text('Start AI'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('host_ai_bubble_stop')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.getTopLeft(find.text('Mini-program body')), before);
      await tester.tap(find.byKey(const ValueKey('host_ai_bubble_stop')));
      await tester.pump();
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('host_ai_bubble')))
            .properties
            .value,
        'AI task cancelled',
      );
      response.complete(
        PhoneAiReply(decision: {'action': 'tap', 'targetId': 'n1'}),
      );
      await tester.pump();
      expect(interactions, 0);
      expect(model.closed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone controls remain usable above a modal mini-program route', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PhoneAiTestWorkspace(
            appId: 'food',
            dispatch: (_) async => _snapshot(),
            navigatorKey: navigator,
            child: child!,
          ),
          home: const Scaffold(body: Text('Mini-program body')),
        ),
      );
      unawaited(
        showDialog<void>(
          context: navigator.currentState!.overlay!.context,
          builder: (_) => const AlertDialog(title: Text('Order review')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('host_ai_bubble')).hitTestable(),
        findsOneWidget,
      );
      expect(
        _semanticsLabels(tester).any((label) => label.contains('AI assistant')),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
      await tester.pumpAndSettle();
      expect(find.text('AI assistant'), findsOneWidget);
      expect(find.text('Start AI').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Minimize'));
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
  });
}

List<String> _semanticsLabels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    labels.add(node.getSemanticsData().label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return labels;
}

class _Model implements PhoneAiModel {
  _Model(this.reply);
  final Future<PhoneAiReply> Function(int call) reply;
  final snapshots = <Map<String, dynamic>>[];
  int calls = 0;
  bool closed = false;
  @override
  Future<PhoneAiReply> decide({
    required String goal,
    required Map<String, dynamic> snapshot,
    required List<String> progress,
  }) {
    snapshots.add(snapshot);
    return reply(++calls);
  }

  @override
  void close() => closed = true;
}
