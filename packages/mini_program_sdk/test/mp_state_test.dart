import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('MpStore', () {
    test('puts, reads, sets, removes, and clears nested state', () {
      final store = MpStore();

      store.put('product.selected', <String, Object?>{
        'id': 'p1',
        'name': 'Scholarship',
      });
      expect(
        store.get<Map<String, dynamic>>('product.selected'),
        <String, dynamic>{'id': 'p1', 'name': 'Scholarship'},
      );

      store.set('product.selected.name', 'Updated');
      expect(store.get<String>('product.selected.name'), 'Updated');

      store.remove('product.selected.name');
      expect(store.get<String>('product.selected.name'), isNull);

      store.clear();
      expect(store.get<Map<String, dynamic>>('product.selected'), isNull);

      store.dispose();
    });

    test('watchers update only for related state paths', () {
      final store = MpStore();
      final count = store.watch('count');
      final product = store.watch('product.selected');

      var countNotifications = 0;
      var productNotifications = 0;
      count.addListener(() => countNotifications += 1);
      product.addListener(() => productNotifications += 1);

      store.set('other', 1);
      expect(countNotifications, 0);
      expect(productNotifications, 0);

      store.set('count', 1);
      expect(count.value, 1);
      expect(countNotifications, 1);
      expect(productNotifications, 0);

      store.set('product.selected.name', 'Award');
      expect(product.value, <String, dynamic>{'name': 'Award'});
      expect(productNotifications, 1);

      store.clear();
      expect(count.value, isNull);
      expect(product.value, isNull);

      store.dispose();
    });

    test(
      'collection reads are defensive and parent watchers see nested writes',
      () {
        final store = MpStore()
          ..set('profile', <String, Object?>{'name': 'Ada'});
        final profile = store.watch('profile');
        var notifications = 0;
        profile.addListener(() => notifications += 1);

        final read = store.get<Map<String, dynamic>>('profile')!;
        read['name'] = 'Mutated outside store';
        expect(store.get<String>('profile.name'), 'Ada');

        store.set('profile.name', 'Grace');
        expect(profile.value, <String, dynamic>{'name': 'Grace'});
        expect(notifications, 1);
        store.dispose();
      },
    );

    test('rejects unsafe keys and disposed access', () {
      final store = MpStore();
      expect(() => store.set('auth.token', 'secret'), throwsArgumentError);
      expect(() => store.set('Count', 1), throwsArgumentError);

      store.dispose();
      expect(() => store.get<Object?>('count'), throwsStateError);
    });

    test('batches updates atomically and notifies each watcher once', () {
      final store = MpStore();
      final cart = store.watch('cart');
      var notifications = 0;
      cart.addListener(() => notifications += 1);

      store.batchUpdates(() {
        store.set('cart.count', 2);
        store.batchUpdates(() {
          store.set('cart.total', 80);
          store.set('cart.ready', true);
        });
      });

      expect(cart.value, <String, dynamic>{
        'count': 2,
        'total': 80,
        'ready': true,
      });
      expect(notifications, 1);

      expect(
        () => store.batchUpdates(() {
          store.set('cart.count', 9);
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(store.get<int>('cart.count'), 2);
      expect(notifications, 1);
    });

    test('enforces every live-state limit and preserves prior values', () {
      final valueLimited = MpStore(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 100,
          maxEntries: 20,
          maxValueBytes: 5,
          maxDepth: 10,
        ),
      )..set('value', 'ok');
      expect(
        () => valueLimited.set('value', '123456'),
        throwsA(isA<MiniProgramStateLimitException>()),
      );
      expect(valueLimited.get<String>('value'), 'ok');

      final entryLimited = MpStore(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 100,
          maxEntries: 2,
          maxValueBytes: 50,
          maxDepth: 10,
        ),
      );
      expect(
        () => entryLimited.set('items', <int>[1, 2]),
        throwsA(isA<MiniProgramStateLimitException>()),
      );

      final depthLimited = MpStore(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 100,
          maxEntries: 10,
          maxValueBytes: 50,
          maxDepth: 2,
        ),
      );
      expect(
        () => depthLimited.set('root', <String, Object?>{
          'child': <String, Object?>{'leaf': true},
        }),
        throwsA(isA<MiniProgramStateLimitException>()),
      );

      final byteLimited = MpStore(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 12,
          maxEntries: 10,
          maxValueBytes: 10,
          maxDepth: 10,
        ),
      );
      expect(
        () => byteLimited.set('value', 'long'),
        throwsA(isA<MiniProgramStateLimitException>()),
      );
      expect(() => valueLimited.set('number', double.nan), throwsArgumentError);
    });

    test('rolls back a batch when its final state exceeds policy', () {
      final store = MpStore(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 30,
          maxEntries: 10,
          maxValueBytes: 20,
          maxDepth: 10,
        ),
      )..set('stable', 1);

      expect(
        () => store.batchUpdates(() {
          store.set('first', '1234567890');
          store.set('second', '1234567890');
        }),
        throwsA(isA<MiniProgramStateLimitException>()),
      );
      expect(store.toBindingData(), <String, dynamic>{'stable': 1});
    });
  });
}
