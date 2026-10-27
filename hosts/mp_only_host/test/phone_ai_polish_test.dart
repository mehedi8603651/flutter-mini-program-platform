import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_only_host/phone_ai/phone_ai_model.dart';
import 'package:mp_only_host/phone_ai/phone_ai_runner.dart';

const _fast = PhoneAiLimits(
  observationInterval: Duration.zero,
  actionInterval: Duration.zero,
);

Map<String, dynamic> _view({
  int revision = 1,
  String status = 'ready',
  String session = 'one',
  String label = 'Add tea',
}) => {
  'appId': 'tea',
  'sessionId': session,
  'screenId': 'home',
  'revision': revision,
  'status': status,
  'canGoBack': false,
  'nodes': [
    {
      'id': 'n1',
      'role': 'button',
      'label': label,
      'actions': ['tap'],
    },
  ],
};

PhoneAiReply _finish([String action = 'done']) => PhoneAiReply(
  decision: {
    'action': action,
    'message': action == 'needsInput'
        ? 'Which tea would you like?'
        : 'The current screen shows the result.',
  },
);
PhoneAiReply _tap({int tokens = 0, double? cost}) => PhoneAiReply(
  decision: {'action': 'tap', 'targetId': 'n1'},
  tokens: tokens,
  costUsd: cost,
);

void main() {
  test(
    'Luna is the default and model requests contain only current visible context',
    () {
      expect(phoneAiModelId, 'openai/gpt-6-luna');
      final view = _view()
        ..['rawState'] = 'private'
        ..['backend'] = 'private';
      (view['nodes'] as List).add({
        'id': 'n2',
        'role': 'checkbox',
        'label': 'Reusable',
        'checked': true,
        'actions': ['tap'],
        'rawAction': 'private',
      });
      final body = OpenRouterPhoneAiModel.requestBody(
        model: phoneAiModelId,
        goal: 'Choose tea',
        snapshot: view,
        progress: List.generate(20, (i) => 'Step $i ${'x' * 200}'),
      );
      final context =
          jsonDecode((body['messages'] as List)[1]['content'] as String) as Map;
      expect(context.keys, unorderedEquals(['goal', 'screen', 'progress']));
      expect(jsonEncode(context), isNot(contains('private')));
      expect(jsonEncode(context), isNot(contains('sessionId')));
      expect(jsonEncode(context), isNot(contains('revision')));
      expect((context['progress'] as List), hasLength(8));
      expect(
        (context['progress'] as List).every(
          (entry) => (entry as String).length <= 160,
        ),
        isTrue,
      );
      expect(context['screen']['nodes'][1]['checked'], isTrue);
      expect(body['response_format']['type'], 'json_schema');
      expect(body['response_format']['json_schema']['strict'], isTrue);
    },
  );

  for (final action in ['done', 'needsInput', 'blocked']) {
    test(
      '$action requires a bounded explanation and has its own outcome',
      () async {
        final decision = {
          'action': action,
          'message': 'Visible explanation',
          'targetId': null,
          'text': null,
        };
        expect(PhoneAiReply.validateDecision(decision, _view()), {
          'action': action,
          'message': 'Visible explanation',
        });
        for (final invalid in [
          {'action': action},
          {'action': action, 'message': ''},
          {'action': action, 'message': 'x' * 241},
          {'action': action, 'message': 'Reason', 'targetId': 'n1'},
          {'action': action, 'message': 'Reason', 'text': 'unexpected'},
        ]) {
          expect(
            () => PhoneAiReply.validateDecision(invalid, _view()),
            throwsFormatException,
          );
        }
        var interactions = 0;
        final model = _Model((_, _) async => _finish(action));
        final runner = PhoneAiRunner(
          appId: 'tea',
          isForeground: () => true,
          limits: _fast,
          modelFactory: () => model,
          dispatch: (request) async {
            if (request['method'] == 'interact') interactions++;
            return _view();
          },
        );
        await runner.start('Choose tea');
        expect(runner.outcome, switch (action) {
          'done' => PhoneAiOutcome.completed,
          'needsInput' => PhoneAiOutcome.needsInput,
          _ => PhoneAiOutcome.blocked,
        });
        expect(runner.message, isNotEmpty);
        expect(interactions, 0);
        runner.dispose();
      },
    );
  }

  test('incomplete and disabled or protected model choices are rejected', () {
    final response = {
      'choices': [
        {
          'finish_reason': 'length',
          'message': {
            'content': jsonEncode({
              'action': 'done',
              'message': 'Looks complete',
            }),
          },
        },
      ],
    };
    expect(() => PhoneAiReply.parse(response, _view()), throwsFormatException);
    for (final flag in ['enabled', 'protected']) {
      final view = _view();
      view['nodes'][0][flag] = flag == 'protected';
      expect(
        () => PhoneAiReply.validateDecision({
          'action': 'tap',
          'targetId': 'n1',
        }, view),
        throwsFormatException,
      );
    }
  });

  test(
    'repeated unchanged views stop despite new revisions and node IDs',
    () async {
      var interactions = 0;
      var observations = 0;
      final model = _Model(
        (snapshot, _) async => PhoneAiReply(
          decision: {'action': 'tap', 'targetId': snapshot['nodes'][0]['id']},
        ),
      );
      final runner = PhoneAiRunner(
        appId: 'tea',
        isForeground: () => true,
        limits: _fast,
        modelFactory: () => model,
        dispatch: (request) async {
          if (request['method'] == 'observe') {
            final view = _view(revision: interactions + 1);
            view['nodes'][0]['id'] = 'n${++observations}';
            return view;
          }
          interactions++;
          return {'status': 'completed'};
        },
      );
      await runner.start('Choose tea');
      expect(runner.outcome, PhoneAiOutcome.blocked);
      expect(runner.message, contains('no visible progress'));
      expect(interactions, 3);
      expect(model.calls, 3);
      runner.dispose();
    },
  );

  test(
    'a navigation cycle stops while changing quantities count as progress',
    () async {
      for (final cycle in [true, false]) {
        var interactions = 0;
        final model = _Model((_, _) async => _tap());
        final runner = PhoneAiRunner(
          appId: 'tea',
          isForeground: () => true,
          limits: _fast,
          modelFactory: () => model,
          dispatch: (request) async {
            if (request['method'] == 'observe') {
              return _view(
                revision: interactions + 1,
                label: 'Quantity ${cycle ? interactions % 2 : interactions}',
              );
            }
            interactions++;
            return {'status': 'completed'};
          },
        );
        await runner.start('Choose tea');
        expect(
          runner.outcome,
          cycle ? PhoneAiOutcome.blocked : PhoneAiOutcome.limited,
        );
        expect(interactions, cycle ? lessThan(16) : 16);
        expect(runner.history.length, lessThanOrEqualTo(8));
        runner.dispose();
      }
    },
  );

  test(
    'pending screen work settles without replaying the accepted action',
    () async {
      var interactions = 0;
      var polls = 0;
      final model = _Model(
        (_, _) async => interactions == 0 ? _tap() : _finish(),
      );
      final runner = PhoneAiRunner(
        appId: 'tea',
        isForeground: () => true,
        limits: _fast,
        modelFactory: () => model,
        dispatch: (request) async {
          if (request['method'] == 'interact') {
            interactions++;
            return {'status': 'pending'};
          }
          if (interactions > 0 && ++polls < 5) return _view(status: 'pending');
          return _view(
            revision: interactions + 1,
            label: interactions == 0 ? 'Add tea' : 'Added tea',
          );
        },
      );
      await runner.start('Choose tea');
      expect(runner.outcome, PhoneAiOutcome.completed);
      expect(interactions, 1);
      expect(polls, greaterThanOrEqualTo(5));
      expect(model.calls, 2);
      runner.dispose();
    },
  );

  test(
    'a terminal decision cannot claim success after the screen changes',
    () async {
      var revision = 1;
      final model = _Model((_, _) async {
        revision++;
        return _finish();
      });
      final runner = PhoneAiRunner(
        appId: 'tea',
        isForeground: () => true,
        limits: _fast,
        modelFactory: () => model,
        dispatch: (_) async => _view(revision: revision),
      );
      await runner.start('Choose tea');
      expect(runner.outcome, PhoneAiOutcome.stopped);
      expect(runner.message, contains('screen changed'));
      runner.dispose();
    },
  );

  test(
    'Stop returns promptly and an old reply cannot affect a continued run',
    () async {
      final started = Completer<void>();
      final delayed = Completer<PhoneAiReply>();
      final first = _Model((_, _) {
        started.complete();
        return delayed.future;
      });
      final second = _Model((_, _) async => _finish());
      var factories = 0;
      var interactions = 0;
      final runner = PhoneAiRunner(
        appId: 'tea',
        isForeground: () => true,
        limits: _fast,
        modelFactory: () => factories++ == 0 ? first : second,
        dispatch: (request) async {
          if (request['method'] == 'interact') interactions++;
          return _view();
        },
      );
      final oldRun = runner.start('Choose tea');
      await started.future;
      runner.stop();
      await oldRun.timeout(const Duration(seconds: 1));
      expect(first.closes, 1);
      await runner.start('Choose tea', continuePrevious: true);
      delayed.complete(_tap(tokens: 900));
      await Future<void>.delayed(Duration.zero);
      expect(runner.outcome, PhoneAiOutcome.completed);
      expect(interactions, 0);
      expect(runner.tokens, 0);
      expect(first.closes, 1);
      runner.dispose();
    },
  );

  for (final phase in ['Thinking', 'Applying']) {
    test(
      'stopping from a $phase listener prevents the next operation',
      () async {
        final model = _Model((_, _) async => _tap());
        var interactions = 0;
        final runner = PhoneAiRunner(
          appId: 'tea',
          isForeground: () => true,
          limits: _fast,
          modelFactory: () => model,
          dispatch: (request) async {
            if (request['method'] == 'interact') interactions++;
            return _view();
          },
        );
        runner.addListener(() {
          if (runner.running && runner.status.startsWith(phase)) runner.stop();
        });
        await runner.start('Choose tea');
        expect(runner.outcome, PhoneAiOutcome.stopped);
        expect(model.calls, phase == 'Thinking' ? 0 : 1);
        expect(interactions, 0);
        expect(model.closes, 1);
        runner.dispose();
      },
    );
  }

  test(
    'explicit cancellation ends active work and a fresh run ignores late replies',
    () async {
      final waiting = Completer<PhoneAiReply>();
      final started = Completer<void>();
      final first = _Model((_, _) {
        started.complete();
        return waiting.future;
      });
      final second = _Model((_, _) async => _finish());
      var factories = 0;
      var interactions = 0;
      var revision = 1;
      final runner = PhoneAiRunner(
        appId: 'tea',
        isForeground: () => true,
        limits: _fast,
        modelFactory: () => factories++ == 0 ? first : second,
        dispatch: (request) async {
          if (request['method'] == 'interact') interactions++;
          return _view(revision: revision);
        },
      );
      final old = runner.start('Choose tea');
      await started.future;
      runner.cancel();
      expect(runner.running, isFalse);
      expect(runner.canContinue, isFalse);
      expect(runner.outcome, PhoneAiOutcome.cancelled);
      revision = 2;
      await runner.start('Choose tea');
      waiting.complete(_tap(tokens: 700));
      await old;
      expect(runner.outcome, PhoneAiOutcome.completed);
      expect(runner.tokens, 0);
      expect(second.views.single['revision'], 2);
      expect(second.progress.single, isEmpty);
      expect(interactions, 0);
      expect(first.closes, 1);
      runner.dispose();
    },
  );

  for (final outcome in ['blocked', 'needsInput']) {
    test(
      'a $outcome task can be explicitly cancelled without resuming it',
      () async {
        final model = _Model((_, _) async => _finish(outcome));
        var interactions = 0;
        final runner = PhoneAiRunner(
          appId: 'tea',
          isForeground: () => true,
          limits: _fast,
          modelFactory: () => model,
          dispatch: (request) async {
            if (request['method'] == 'interact') interactions++;
            return _view();
          },
        );
        await runner.start('Choose tea');
        expect(runner.canContinue, isTrue);
        runner.cancel();
        expect(runner.canContinue, isFalse);
        expect(runner.outcome, PhoneAiOutcome.cancelled);
        runner.cancel();
        await Future<void>.delayed(Duration.zero);
        expect(model.calls, 1);
        expect(interactions, 0);
        runner.dispose();
      },
    );
  }

  for (final change in ['same session', 'new session', 'new goal']) {
    test(
      'continuing uses a fresh view and scopes history for $change',
      () async {
        var revision = 1;
        var session = 'one';
        var factories = 0;
        var interactions = 0;
        final first = _Model((_, _) async => _tap());
        final second = _Model((_, _) async => _finish());
        final runner = PhoneAiRunner(
          appId: 'tea',
          isForeground: () => true,
          limits: _fast,
          modelFactory: () => factories++ == 0 ? first : second,
          dispatch: (request) async {
            if (request['method'] == 'observe') {
              return _view(revision: revision, session: session);
            }
            interactions++;
            revision++;
            return {'status': 'rejected', 'code': 'stale_view'};
          },
        );
        await runner.start('Choose tea');
        expect(runner.outcome, PhoneAiOutcome.stopped);
        if (change == 'new session') session = 'two';
        await runner.start(
          change == 'new goal' ? 'Review tea' : 'Choose tea',
          continuePrevious: true,
        );
        expect(second.views.single['revision'], 2);
        expect(
          second.progress.single,
          change == 'same session' ? hasLength(1) : isEmpty,
        );
        expect(interactions, 1);
        expect(runner.outcome, PhoneAiOutcome.completed);
        runner.dispose();
      },
    );
  }

  test(
    'uncertain dispatch outcomes stop and are retained for a fresh continuation',
    () async {
      final delayed = Completer<Map<String, dynamic>>();
      var interactions = 0;
      final runner = PhoneAiRunner(
        appId: 'tea',
        isForeground: () => true,
        limits: const PhoneAiLimits(
          observationInterval: Duration.zero,
          actionInterval: Duration.zero,
          dispatchTimeout: Duration(milliseconds: 30),
        ),
        modelFactory: () => _Model((_, _) async => _tap()),
        dispatch: (request) async {
          if (request['method'] == 'observe') return _view();
          interactions++;
          return delayed.future;
        },
      );
      await runner.start('Choose tea');
      expect(runner.outcome, PhoneAiOutcome.stopped);
      expect(runner.message, contains('uncertain'));
      expect(runner.history.single, contains('not yet confirmed'));
      delayed.complete({'status': 'completed'});
      await Future<void>.delayed(Duration.zero);
      expect(interactions, 1);
      runner.dispose();
    },
  );

  for (final kind in ['step', 'tokens', 'cost', 'time', 'screen']) {
    test('$kind limit stops further model requests and interactions', () async {
      var interactions = 0;
      final model = _Model((_, _) async {
        if (kind == 'time') {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
        return _tap(tokens: 100, cost: 0.01);
      });
      final limits = PhoneAiLimits(
        maxDecisions: kind == 'step' ? 1 : 16,
        maxTokens: kind == 'tokens' ? 100 : 20000,
        maxReportedCostUsd: kind == 'cost' ? 0.005 : 0.05,
        maxDuration: kind == 'time'
            ? const Duration(milliseconds: 30)
            : const Duration(minutes: 5),
        screenTimeout: const Duration(milliseconds: 30),
        observationInterval: Duration.zero,
        actionInterval: Duration.zero,
      );
      final runner = PhoneAiRunner(
        appId: 'tea',
        isForeground: () => true,
        limits: limits,
        modelFactory: () => model,
        dispatch: (request) async {
          if (request['method'] == 'observe') {
            return _view(
              status: kind == 'screen' ? 'pending' : 'ready',
              revision: interactions + 1,
              label: 'Quantity $interactions',
            );
          }
          interactions++;
          return {'status': 'completed'};
        },
      );
      await runner.start('Choose tea');
      expect(
        runner.outcome,
        kind == 'screen' ? PhoneAiOutcome.stopped : PhoneAiOutcome.limited,
      );
      expect(model.calls, kind == 'screen' ? 0 : 1);
      expect(interactions, (kind == 'time' || kind == 'screen') ? 0 : 1);
      expect(model.closes, 1);
      runner.dispose();
    });
  }

  for (final failure in <Object>[
    const SocketException('private-provider-data'),
    const HandshakeException('private-provider-data'),
    const FormatException('private-provider-data'),
    const PhoneAiHttpFailure(429),
  ]) {
    test(
      '${failure.runtimeType} fails without leaking provider error details',
      () async {
        final runner = PhoneAiRunner(
          appId: 'tea',
          isForeground: () => true,
          limits: _fast,
          modelFactory: () => _Model((_, _) async => throw failure),
          dispatch: (_) async => _view(),
        );
        await runner.start('Choose tea');
        expect(runner.outcome, PhoneAiOutcome.failed);
        expect(
          '${runner.status} ${runner.message}',
          isNot(contains('private-provider-data')),
        );
        runner.dispose();
      },
    );
  }
}

class _Model implements PhoneAiModel {
  _Model(this.reply);
  final Future<PhoneAiReply> Function(Map<String, dynamic>, List<String>) reply;
  final views = <Map<String, dynamic>>[];
  final progress = <List<String>>[];
  int calls = 0;
  int closes = 0;
  @override
  Future<PhoneAiReply> decide({
    required String goal,
    required Map<String, dynamic> snapshot,
    required List<String> progress,
  }) {
    calls++;
    views.add(snapshot);
    this.progress.add(List.of(progress));
    return reply(snapshot, progress);
  }

  @override
  void close() {
    closes++;
  }
}
