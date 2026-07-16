import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('MpScreenValidator compatibility', () {
    test('preserves unsupported node failure details', () {
      _expectValidationFailure(
        _screen(_node('video')),
        message: 'Invalid Mp screen JSON: Unsupported Mp node type "video".',
        details: <String, dynamic>{'path': r'$.root.type', 'nodeType': 'video'},
      );
    });

    test('preserves unsupported action failure details', () {
      _expectValidationFailure(
        _screen(
          _node(
            'primaryButton',
            props: <String, dynamic>{
              'label': 'Run',
              'action': <String, dynamic>{
                'type': 'host.run',
                'props': <String, dynamic>{},
              },
            },
          ),
        ),
        message:
            'Invalid Mp screen JSON: Unsupported Mp action type "host.run".',
        details: <String, dynamic>{
          'path': r'$.root.props.action.type',
          'actionType': 'host.run',
        },
      );
    });

    test('preserves malformed property failure details', () {
      final root = _node('text')..['props'] = 'invalid';
      _expectValidationFailure(
        _screen(root),
        message: 'Invalid Mp screen JSON: Mp field must be an object.',
        details: <String, dynamic>{'path': r'$.root.props'},
      );
    });

    test('preserves unsafe binding failure details', () {
      _expectValidationFailure(
        _screen(
          _node('text', props: <String, dynamic>{'data': r'{{secrets.token}}'}),
        ),
        message: 'Invalid Mp screen JSON: unsupported binding path.',
        details: <String, dynamic>{
          'path': r'$.root.props.data',
          'bindingPath': 'secrets.token',
        },
      );
    });

    test('preserves direct child limit failure details', () {
      _expectValidationFailure(
        _screen(
          _node(
            'column',
            children: List<Map<String, dynamic>>.generate(
              MpScreenValidator.maxDirectChildren + 1,
              (_) => _node('text', props: <String, dynamic>{'data': 'Item'}),
            ),
          ),
        ),
        message:
            'Invalid Mp screen JSON: Mp node exceeds the maximum direct child count.',
        details: <String, dynamic>{
          'path': r'$.root.children',
          'maxDirectChildren': MpScreenValidator.maxDirectChildren,
        },
      );
    });
  });
}

Map<String, dynamic> _screen(Map<String, dynamic> root) => <String, dynamic>{
  'schemaVersion': 1,
  'screenId': 'compatibility_home',
  'root': root,
};

Map<String, dynamic> _node(
  String type, {
  Map<String, dynamic> props = const <String, dynamic>{},
  List<Map<String, dynamic>> children = const <Map<String, dynamic>>[],
}) => <String, dynamic>{'type': type, 'props': props, 'children': children};

void _expectValidationFailure(
  Map<String, dynamic> screen, {
  required String message,
  required Map<String, dynamic> details,
}) {
  try {
    const MpScreenValidator().validate(
      screen,
      expectedScreenId: 'compatibility_home',
    );
    fail('Expected MpScreenValidator to reject the screen.');
  } on MiniProgramRenderException catch (error) {
    expect(error.errorCode, MiniProgramErrorCodes.manifestParseFailure);
    expect(error.message, message);
    expect(error.details, details);
  }
}
