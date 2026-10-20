import 'dart:convert';

import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  final action = Mp.state.increment('booking.count');

  test('icon variants serialize explicitly and deterministically', () {
    final builders = <String, MpNode Function()>{
      'standard': () => Mp.floatingActionButton(
        icon: 'add',
        semanticLabel: 'Add booking',
        action: action,
      ),
      'small': () => Mp.floatingActionButton.small(
        icon: 'add',
        semanticLabel: 'Add booking',
        action: action,
      ),
      'large': () => Mp.floatingActionButton.large(
        icon: 'add',
        semanticLabel: 'Add booking',
        action: action,
      ),
    };
    for (final entry in builders.entries) {
      final expected = <String, Object?>{
        'type': 'floatingActionButton',
        'props': <String, Object?>{
          'variant': entry.key,
          'icon': 'add',
          'semanticLabel': 'Add booking',
          'action': action.toJson(),
          'enabled': true,
        },
        'children': <Object?>[],
      };
      expect(entry.value().toJson(), expected);
      expect(
        jsonEncode(entry.value().toJson()),
        jsonEncode(entry.value().toJson()),
      );
    }
  });

  test(
    'extended text-only and icon variants preserve bindings and semantics',
    () {
      final textOnly = Mp.floatingActionButton
          .extended(label: ' Book {{state.booking.count}} ', action: action)
          .toJson();
      expect(textOnly['props'], {
        'variant': 'extended',
        'label': 'Book {{state.booking.count}}',
        'semanticLabel': 'Book {{state.booking.count}}',
        'action': action.toJson(),
        'enabled': true,
      });
      final withIcon = Mp.floatingActionButton
          .extended(
            label: 'Book',
            icon: 'add',
            semanticLabel: 'Create a booking',
            action: action,
          )
          .toJson();
      expect((withIcon['props'] as Map)['icon'], 'add');
      expect((withIcon['props'] as Map)['semanticLabel'], 'Create a booking');
    },
  );

  test('all variants support disabled state and optional literal colors', () {
    for (final builder in [
      Mp.floatingActionButton.call,
      Mp.floatingActionButton.small,
      Mp.floatingActionButton.large,
    ]) {
      final props =
          builder(
                icon: 'edit',
                semanticLabel: 'Edit',
                action: action,
                enabled: false,
                backgroundColor: '#123456',
                foregroundColor: '#FFABCDEF',
              ).toJson()['props']
              as Map;
      expect(props['enabled'], false);
      expect(props['backgroundColor'], '#123456');
      expect(props['foregroundColor'], '#FFABCDEF');
    }
    final props =
        Mp.floatingActionButton
                .extended(
                  label: 'Book',
                  action: action,
                  enabled: false,
                  backgroundColor: '#123456',
                  foregroundColor: '#FFABCDEF',
                )
                .toJson()['props']
            as Map;
    expect(props['enabled'], false);
    expect(props['backgroundColor'], '#123456');
    expect(props['foregroundColor'], '#FFABCDEF');
  });

  test(
    'authoring rejects invalid icons, empty or oversized text and colors',
    () {
      for (final builder in [
        Mp.floatingActionButton.call,
        Mp.floatingActionButton.small,
        Mp.floatingActionButton.large,
      ]) {
        for (final icon in ['', 'notAnIcon', '{{state.icon}}']) {
          expect(
            () => builder(icon: icon, semanticLabel: 'Add', action: action),
            throwsArgumentError,
          );
        }
        for (final text in ['', '   ', 'x' * 513]) {
          expect(
            () => builder(icon: 'add', semanticLabel: text, action: action),
            throwsArgumentError,
          );
        }
        expect(
          () => builder(
            icon: 'add',
            semanticLabel: 'Add',
            action: action,
            backgroundColor: 'red',
          ),
          throwsArgumentError,
        );
        expect(
          () => builder(
            icon: 'add',
            semanticLabel: 'Add',
            action: action,
            foregroundColor: '{{state.color}}',
          ),
          throwsArgumentError,
        );
      }
      for (final text in ['', '   ', 'x' * 513]) {
        expect(
          () => Mp.floatingActionButton.extended(label: text, action: action),
          throwsArgumentError,
        );
        expect(
          () => Mp.floatingActionButton.extended(
            label: 'Book',
            semanticLabel: text,
            action: action,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => Mp.floatingActionButton.extended(
          label: 'Book',
          icon: 'unknown',
          action: action,
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.floatingActionButton.extended(
          label: 'Book',
          action: action,
          backgroundColor: '#ABC',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'standalone namespace is exported through the pure-Dart public barrel',
    () {
      const buttons = MpFloatingActionButton();
      expect(
        buttons(icon: 'add', semanticLabel: 'Add', action: action),
        isA<MpNode>(),
      );
      expect(
        buttons.extended(label: 'Book', action: action).type,
        'floatingActionButton',
      );
    },
  );
}
