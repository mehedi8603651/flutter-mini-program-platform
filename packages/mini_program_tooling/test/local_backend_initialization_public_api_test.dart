import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test(
    'local backend initialization API remains available from the barrel',
    () {
      const initializer = LocalBackendInitializer(templateRootPath: 'template');
      const request = LocalBackendInitRequest(
        backendRootPath: 'backend',
        force: true,
      );
      const result = LocalBackendInitResult(
        backendRootPath: 'backend',
        apiRootPath: 'backend/api',
        serviceDirectoryPath: 'backend/service',
        stateFilePath: 'backend/state.json',
        globalStateFilePath: 'global/state.json',
        createdPaths: <String>['backend/state.json'],
      );
      const exception = LocalBackendInitException('initialization failed');

      expect(initializer, isA<LocalBackendInitializer>());
      expect(request.force, isTrue);
      expect(result.createdPaths, <String>['backend/state.json']);
      expect(exception.toString(), 'initialization failed');
    },
  );
}
