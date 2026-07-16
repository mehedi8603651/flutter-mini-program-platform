import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('nested batches expose staged reads and roll back as one unit', () {
    final store = MpStore()..set('cart.count', 1);
    final cart = store.watch('cart');
    var notifications = 0;
    cart.addListener(() => notifications += 1);

    expect(
      () => store.batchUpdates(() {
        store.set('cart.count', 2);
        expect(store.get<int>('cart.count'), 2);
        store.batchUpdates(() {
          store.set('cart.total', 80);
          expect(store.get<int>('cart.total'), 80);
        });
        throw StateError('rollback outer batch');
      }),
      throwsStateError,
    );

    expect(store.toBindingData(), <String, dynamic>{
      'cart': <String, dynamic>{'count': 1},
    });
    expect(cart.value, <String, dynamic>{'count': 1});
    expect(notifications, 0);

    store.batchUpdates(() {
      store.set('cart.count', 3);
      store.set('cart.total', 120);
    });
    expect(cart.value, <String, dynamic>{'count': 3, 'total': 120});
    expect(notifications, 1);
  });

  test('policy changes remain forbidden and atomic during a batch', () {
    final store = MpStore()..set('stable', 1);

    expect(
      () => store.batchUpdates(() {
        store.set('temporary', 2);
        store.updatePolicy(
          const MiniProgramLiveStatePolicy(
            maxBytes: 1024,
            maxEntries: 10,
            maxValueBytes: 512,
            maxDepth: 8,
          ),
        );
      }),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Cannot update live-state policy during a batch.',
        ),
      ),
    );
    expect(store.toBindingData(), <String, dynamic>{'stable': 1});
    expect(store.policy, const MiniProgramLiveStatePolicy());
  });

  test('quota failures preserve exact details and previous state', () {
    final store = MpStore(
      policy: const MiniProgramLiveStatePolicy(
        maxBytes: 100,
        maxEntries: 20,
        maxValueBytes: 5,
        maxDepth: 10,
      ),
    )..set('value', 'ok');

    expect(
      () => store.set('value', '123456'),
      throwsA(
        isA<MiniProgramStateLimitException>()
            .having((error) => error.metric, 'metric', 'maxValueBytes')
            .having((error) => error.limit, 'limit', 5)
            .having((error) => error.actual, 'actual', 8)
            .having((error) => error.details, 'details', <String, dynamic>{
              'metric': 'maxValueBytes',
              'limit': 5,
              'actual': 8,
            })
            .having(
              (error) => error.toString(),
              'toString',
              'Mini-program live state exceeds maxValueBytes limit (8 > 5).',
            ),
      ),
    );
    expect(store.get<String>('value'), 'ok');
  });

  test(
    'router forwards operation arguments and request IDs unchanged',
    () async {
      final calls = <Object?>[];
      Future<HostActionResult> screenHandler(
        String action,
        String screenId,
        Map<String, dynamic> params,
        String? requestId,
      ) async {
        calls.add(<Object?>[action, screenId, params, requestId]);
        return HostActionResult.success(
          actionName: action,
          requestId: requestId,
        );
      }

      Future<HostActionResult> resultHandler(
        String action,
        Map<String, dynamic> result,
        String? requestId,
      ) async {
        calls.add(<Object?>[action, result, requestId]);
        return HostActionResult.success(
          actionName: action,
          requestId: requestId,
        );
      }

      final router = MpRouter(
        push: (screenId, params, requestId) =>
            screenHandler('push', screenId, params, requestId),
        replace: (screenId, params, requestId) =>
            screenHandler('replace', screenId, params, requestId),
        reset: (screenId, params, requestId) =>
            screenHandler('reset', screenId, params, requestId),
        pop: (result, requestId) => resultHandler('pop', result, requestId),
        popToRoot: (result, requestId) =>
            resultHandler('popToRoot', result, requestId),
        popToScreen: (screenId, result, requestId) async {
          calls.add(<Object?>['popToScreen', screenId, result, requestId]);
          return HostActionResult.success(
            actionName: 'popToScreen',
            requestId: requestId,
          );
        },
      );

      await router.push('details', <String, dynamic>{'id': 1}, 'push-1');
      await router.replace('summary', <String, dynamic>{'tab': 2}, 'replace-1');
      await router.reset('home', const <String, dynamic>{}, 'reset-1');
      await router.pop(<String, dynamic>{'saved': true}, 'pop-1');
      await router.popToRoot(<String, dynamic>{'done': true}, 'root-1');
      await router.popToScreen('checkout', <String, dynamic>{
        'paid': true,
      }, 'screen-1');

      expect(calls, <Object?>[
        <Object?>[
          'push',
          'details',
          <String, dynamic>{'id': 1},
          'push-1',
        ],
        <Object?>[
          'replace',
          'summary',
          <String, dynamic>{'tab': 2},
          'replace-1',
        ],
        <Object?>['reset', 'home', const <String, dynamic>{}, 'reset-1'],
        <Object?>[
          'pop',
          <String, dynamic>{'saved': true},
          'pop-1',
        ],
        <Object?>[
          'popToRoot',
          <String, dynamic>{'done': true},
          'root-1',
        ],
        <Object?>[
          'popToScreen',
          'checkout',
          <String, dynamic>{'paid': true},
          'screen-1',
        ],
      ]);
    },
  );

  test('state and router APIs remain available from the SDK barrel', () {
    final provider = _LiveStatePolicyProvider();
    final manager = MpStateManager(
      policy: provider.liveStatePolicyFor('example'),
    );

    manager.set('screen.ready', true);
    expect(manager.get<bool>('screen.ready'), isTrue);
    expect(validateStateKey(' screen.ready '), 'screen.ready');
    expect(provider, isA<MiniProgramLiveStatePolicyProvider>());
    expect(manager.store, isA<MpStore>());
  });
}

class _LiveStatePolicyProvider implements MiniProgramLiveStatePolicyProvider {
  @override
  MiniProgramLiveStatePolicy liveStatePolicyFor(String miniProgramId) {
    return const MiniProgramLiveStatePolicy();
  }
}
