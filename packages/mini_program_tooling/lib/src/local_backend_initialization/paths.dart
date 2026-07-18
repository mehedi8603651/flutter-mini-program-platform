import 'package:path/path.dart' as p;

import 'dependencies.dart';
import 'models.dart';

LocalBackendWorkspacePaths resolveLocalBackendWorkspacePaths(
  LocalBackendInitializationDependencies dependencies,
  LocalBackendInitRequest request,
) {
  final backendRootPath = p.normalize(
    p.absolute(
      request.backendRootPath ??
          dependencies.stateStore.defaultBackendWorkspaceRootPath(),
    ),
  );
  return LocalBackendWorkspacePaths(
    backendRootPath: backendRootPath,
    apiRootPath: p.join(backendRootPath, 'backend', 'api'),
    serviceDirectoryPath: p.join(
      backendRootPath,
      'backend',
      'local_backend_service',
    ),
  );
}
