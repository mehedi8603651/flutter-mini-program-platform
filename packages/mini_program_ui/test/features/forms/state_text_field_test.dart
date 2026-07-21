import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('serializes a styled state-bound multiline text field', () {
    final node = Mp.stateTextField(
      stateKey: 'editor.body',
      hint: 'Write your note',
      maxLength: 32768,
      minLines: 8,
      maxLines: 20,
      keyboardType: 'multiline',
      textInputAction: 'newline',
      autofocus: true,
      textColor: '#FFF5F5F5',
      hintColor: '#FF999999',
      cursorColor: '#FF8EAD7C',
      backgroundColor: '#FF121212',
      borderColor: '#FF4A4A4A',
      focusedBorderColor: '#FF8EAD7C',
      borderRadius: 6,
      fontSize: 18,
      onSubmitted: Mp.state.set('editor.submitted', true),
    );

    expect(node.type, 'stateTextField');
    expect(node.props, containsPair('stateKey', 'editor.body'));
    expect(node.props, containsPair('maxLength', 32768));
    expect(node.props, containsPair('minLines', 8));
    expect(node.props, containsPair('maxLines', 20));
    expect(node.props, containsPair('keyboardType', 'multiline'));
    expect(node.props, containsPair('textInputAction', 'newline'));
    expect(node.props, containsPair('autofocus', true));
    expect(node.props['onSubmitted'], isA<Map<String, Object?>>());
  });

  test('rejects invalid state text field options', () {
    expect(
      () =>
          Mp.stateTextField(stateKey: 'editor.body', minLines: 4, maxLines: 2),
      throwsArgumentError,
    );
    expect(
      () =>
          Mp.stateTextField(stateKey: 'editor.body', keyboardType: 'markdown'),
      throwsArgumentError,
    );
    expect(
      () => Mp.stateTextField(
        stateKey: 'editor.body',
        initialValue: 'too long',
        maxLength: 3,
      ),
      throwsArgumentError,
    );
  });

  test('serializes a semantic tap wrapper', () {
    final node = Mp.tap(
      semanticLabel: 'Open note',
      action: Mp.state.set('note.opened', true),
      child: Mp.text('Note title'),
    );

    expect(node.type, 'tap');
    expect(node.props, containsPair('semanticLabel', 'Open note'));
    expect(node.props['action'], isA<Map<String, Object?>>());
    expect(node.children, hasLength(1));
  });
}
