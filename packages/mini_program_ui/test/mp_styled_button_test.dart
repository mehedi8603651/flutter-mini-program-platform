import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('styled button and icon button serialize deterministically', () {
    expect(
      Mp.button(
        label: '7',
        action: Mp.state.appendText('calc.expression', '7'),
        height: 68,
        backgroundColor: '#FF252525',
        foregroundColor: '#FFF5F5F5',
        borderColor: '#FF252525',
        borderRadius: 999,
        fontSize: 30,
      ).toJson(),
      <String, Object?>{
        'type': 'button',
        'props': <String, Object?>{
          'action': <String, Object?>{
            'type': 'state.appendText',
            'props': <String, Object?>{
              'key': 'calc.expression',
              'text': '7',
              'maxLength': 4096,
            },
          },
          'backgroundColor': '#FF252525',
          'borderColor': '#FF252525',
          'borderRadius': 999,
          'borderWidth': 0,
          'fontSize': 30,
          'fontWeight': 'medium',
          'foregroundColor': '#FFF5F5F5',
          'height': 68,
          'label': '7',
        },
        'children': <Object?>[],
      },
    );

    expect(
      Mp.iconButton(
        'history',
        semanticLabel: 'Calculation history',
        action: Mp.navigation.openScreen('calculator_history'),
        size: 48,
        iconSize: 29,
        color: '#FF9A9A9A',
        backgroundColor: '#FF000000',
        borderRadius: 24,
      ).toJson(),
      <String, Object?>{
        'type': 'iconButton',
        'props': <String, Object?>{
          'action': <String, Object?>{
            'type': 'navigation.openScreen',
            'props': <String, Object?>{'screenId': 'calculator_history'},
          },
          'backgroundColor': '#FF000000',
          'borderColor': '#00000000',
          'borderRadius': 24,
          'borderWidth': 0,
          'color': '#FF9A9A9A',
          'iconSize': 29,
          'name': 'history',
          'semanticLabel': 'Calculation history',
          'size': 48,
        },
        'children': <Object?>[],
      },
    );
  });

  test('styled controls reject invalid authoring values', () {
    expect(
      () => Mp.button(label: '', action: Mp.state.set('test.value', true)),
      throwsArgumentError,
    );
    expect(
      () => Mp.iconButton(
        'video',
        semanticLabel: 'Video',
        action: Mp.state.set('test.value', true),
      ),
      throwsArgumentError,
    );
    expect(
      () => Mp.iconButton(
        'history',
        semanticLabel: 'History',
        action: Mp.state.set('test.value', true),
        size: 24,
        iconSize: 25,
      ),
      throwsArgumentError,
    );
  });

  test('generic activity icons are available to mini-programs', () {
    for (final name in <String>[
      'brain',
      'trophy',
      'timer',
      'close',
      'refresh',
      'bolt',
    ]) {
      expect(
        Mp.icon(name, semanticLabel: '$name icon').toJson(),
        <String, Object?>{
          'type': 'icon',
          'props': <String, Object?>{
            'name': name,
            'semanticLabel': '$name icon',
            'size': 20,
          },
          'children': <Object?>[],
        },
      );
    }
  });
}
