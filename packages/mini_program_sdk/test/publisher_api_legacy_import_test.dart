import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/network/mini_program_backend_connector.dart'
    as connector;
import 'package:mini_program_sdk/network/mini_program_backend_store.dart'
    as store;

void main() {
  test('historical Publisher API import paths retain public declarations', () {
    expect(const connector.MiniProgramPublisherApiPolicy(), isNotNull);
    expect(connector.MiniProgramBackendHttpHeaders.appId, isNotEmpty);
    expect(
      const connector.MiniProgramBackendRequest(
        miniProgramId: 'app',
        endpoint: 'home',
      ),
      isNotNull,
    );
    expect(const connector.DisabledMiniProgramBackendConnector(), isNotNull);
    expect(
      const store.MiniProgramBackendQuery(requestId: 'home', endpoint: 'home'),
      isNotNull,
    );
    expect(
      const store.MiniProgramPagedBackendQuery(
        requestId: 'items',
        endpoint: 'items',
      ),
      isNotNull,
    );
    expect(store.MiniProgramBackendStore(), isNotNull);
  });
}
