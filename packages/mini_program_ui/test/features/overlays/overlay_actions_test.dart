import 'dart:convert';

import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('panel authoring', () {
    final content = Mp.column(
      children: [
        Mp.text('Shop menu'),
        Mp.primaryButton(label: 'Orders', action: Mp.state.set('shop.tab', 1)),
      ],
    );

    test('drawers serialize explicit sides and nested nodes/actions', () {
      for (final entry in {
        'left': Mp.drawer.left,
        'right': Mp.drawer.right,
      }.entries) {
        final action = entry.value(child: content);
        expect(action.type, 'ui.drawer.open');
        expect(action.props['side'], entry.key);
        expect(action.props['child'], content.toJson());
        expect(action.props['width'], 320);
        expect(action.props['dismissible'], isTrue);
        expect(action.props['enableDrag'], isTrue);
        expect(jsonEncode(action), jsonEncode(action.toJson()));
      }
    });

    test('sheets serialize directions, sizing and drag options', () {
      for (final entry in {
        'top': Mp.sheet.top,
        'bottom': Mp.sheet.bottom,
      }.entries) {
        final action = entry.value(
          child: content,
          heightFactor: 0.8,
          maxWidth: 700,
          dismissible: false,
          enableDrag: false,
          showDragHandle: false,
          padding: 8,
          borderRadius: 12,
          backgroundColor: '#123456',
          barrierColor: '#80000000',
          semanticLabel: 'Shop filters',
        );
        expect(action.type, 'ui.sheet.open');
        expect(action.props['side'], entry.key);
        expect(action.props['heightFactor'], 0.8);
        expect(action.props['maxWidth'], 700);
        expect(action.props['showDragHandle'], isFalse);
        expect(action.props['enableDrag'], isFalse);
        expect(action.props['dismissible'], isFalse);
        expect(action.props['backgroundColor'], '#123456');
      }
    });

    test('simple dialog keeps its existing JSON contract', () {
      expect(Mp.dialog(title: 'Saved', message: 'Order saved').toJson(), {
        'type': 'ui.dialog',
        'props': {
          'title': 'Saved',
          'message': 'Order saved',
          'confirmLabel': 'OK',
        },
      });
    });

    test('confirmation callbacks remain serialized actions', () {
      final confirm = Mp.state.set('order.confirmed', true);
      final cancel = Mp.state.set('order.confirmed', false);
      final action = Mp.dialog(
        message: 'Confirm order?',
        onConfirm: confirm,
        onCancel: cancel,
      );
      expect(action.props['onConfirm'], confirm.toJson());
      expect(action.props['onCancel'], cancel.toJson());
      expect(action.props['cancelLabel'], 'Cancel');
    });

    test('custom dialog content owns its action buttons', () {
      final action = Mp.dialog.custom(child: content, width: 500);
      expect(action.type, 'ui.dialog');
      expect(action.props['child'], content.toJson());
      expect(action.props['width'], 500);
      expect(action.props, isNot(contains('message')));
      expect(action.props, isNot(contains('confirmLabel')));
    });

    test('close actions are explicit and contain no navigation payload', () {
      expect(Mp.drawer.close().toJson(), {
        'type': 'ui.drawer.close',
        'props': {},
      });
      expect(Mp.sheet.close().toJson(), {
        'type': 'ui.sheet.close',
        'props': {},
      });
      expect(Mp.dialog.close().toJson(), {
        'type': 'ui.dialog.close',
        'props': {},
      });
    });

    test('state bindings are preserved for runtime evaluation', () {
      final action = Mp.drawer.right(child: Mp.text('{{state.shop.name}}'));
      expect(
        (action.props['child'] as Map)['props'],
        containsPair('data', '{{state.shop.name}}'),
      );
    });

    test('invalid sizes, colors and empty labels fail at authoring time', () {
      for (final width in [0, 79, 1201, double.nan, double.infinity]) {
        expect(
          () => Mp.drawer.left(child: content, width: width),
          throwsArgumentError,
        );
        expect(
          () => Mp.dialog.custom(child: content, width: width),
          throwsArgumentError,
        );
      }
      for (final factor in [0, 0.09, 1.1, double.nan, double.infinity]) {
        expect(
          () => Mp.sheet.bottom(child: content, heightFactor: factor),
          throwsArgumentError,
        );
      }
      expect(
        () => Mp.drawer.right(child: content, padding: -1),
        throwsArgumentError,
      );
      expect(
        () => Mp.sheet.top(child: content, borderRadius: 65),
        throwsArgumentError,
      );
      expect(
        () => Mp.dialog.custom(child: content, backgroundColor: 'blue'),
        throwsArgumentError,
      );
      expect(
        () => Mp.drawer.left(child: content, semanticLabel: ' '),
        throwsArgumentError,
      );
      expect(() => Mp.dialog(message: ''), throwsArgumentError);
      expect(
        () => Mp.dialog(message: 'OK', cancelLabel: ''),
        throwsArgumentError,
      );
    });
  });
}
