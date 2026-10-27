import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> request() => {
    'requestId': 'r1',
    'sessionId': 's1',
    'revision': 1,
    'action': 'enterText',
    'targetId': 'n1',
    'text': 'No onions',
  };

  test('round trips bounded typed interaction requests', () {
    expect(
      MiniProgramInteractionRequest.fromJson(request()).toJson(),
      request(),
    );
    final back = MiniProgramInteractionRequest(
      requestId: 'r2',
      sessionId: 's1',
      revision: 2,
      action: MiniProgramInteractionAction.back,
    );
    expect(back.toJson().containsKey('targetId'), isFalse);
  });

  test(
    'rejects arbitrary actions, authority claims and malformed requests',
    () {
      for (final changes in <Map<String, dynamic>>[
        {'action': 'backend.call'},
        {'userGesture': true},
        {'revision': 0},
        {'revision': 1.0},
        {'sessionId': '../app'},
        {'targetId': null},
        {'text': List.filled(4097, 'a').join()},
        {'action': 'tap'},
        {'action': 'back'},
        {'text': 8},
      ]) {
        expect(
          () => MiniProgramInteractionRequest.fromJson({
            ...request(),
            ...changes,
          }),
          throwsFormatException,
          reason: changes.keys.join(','),
        );
      }
    },
  );

  test('protected values are excluded from serialized observations', () {
    final node = MiniProgramInteractionNode(
      id: 'n1',
      role: 'protectedField',
      label: 'Password',
      value: 'never-export',
      protected: true,
      actions: [],
    );
    expect(node.toJson().containsKey('value'), isFalse);
    expect(
      () => node.actions.add(MiniProgramInteractionAction.tap),
      throwsUnsupportedError,
    );
  });
}
