import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('renderer validation APIs remain available from the public barrel', () {
    const renderer = MpScreenRenderer();
    const validator = MpScreenValidator();
    const runner = MpActionRunner();

    expect(renderer.supportedSchemaVersions, const <int>{1});
    expect(runner, isA<MpActionRunner>());
    expect(
      () => validator.validate(<String, dynamic>{
        'schemaVersion': 1,
        'screenId': 'compatibility_home',
        'root': <String, dynamic>{
          'type': 'text',
          'props': <String, dynamic>{'data': 'Compatible'},
          'children': <Object?>[],
        },
      }, expectedScreenId: 'compatibility_home'),
      returnsNormally,
    );
  });
}
