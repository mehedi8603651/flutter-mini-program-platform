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

    test('rejects unsafe keys and disposed access', () {
      final store = MpStore();
      expect(() => store.set('auth.token', 'secret'), throwsArgumentError);
      expect(() => store.set('Count', 1), throwsArgumentError);

      store.dispose();
      expect(() => store.get<Object?>('count'), throwsStateError);
    });
  });
}
