import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/auth/mini_program_auth.dart' as auth;

void main() {
  test('historical auth import path retains public declarations', () {
    expect(const auth.MiniProgramAuthBackendPaths(), isNotNull);
    expect(auth.MiniProgramAuthHttpHeaders.authorization, 'authorization');
    expect(const auth.MiniProgramAuthUser(uid: 'user'), isNotNull);
    expect(auth.MiniProgramAuthStatus.values, hasLength(8));
    expect(
      auth.InMemoryMiniProgramAuthStore(),
      isA<auth.MiniProgramAuthStore>(),
    );
    expect(
      auth.MiniProgramAuthController.inMemory(),
      isA<auth.MiniProgramAuthController>(),
    );
  });
}
