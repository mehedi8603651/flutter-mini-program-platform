import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf/shelf.dart';

import 'package:local_backend_service/local_backend_service.dart';

Future<void> main(List<String> arguments) async {
  final configuration = _ServerConfiguration.fromEnvironment(arguments);
  final apiRootDirectory = Directory(configuration.apiRootPath);

  if (!await apiRootDirectory.exists()) {
    stderr.writeln('Backend API root does not exist: ${apiRootDirectory.path}');
    exitCode = 64;
    return;
  }

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(
        createLocalBackendHandler(apiRootDirectory: apiRootDirectory),
      );

  final server = await shelf_io.serve(
    handler,
    configuration.bindAddress,
    configuration.port,
  );

  stdout.writeln(
    'local_backend_service listening on http://${server.address.host}:${server.port}',
  );
  stdout.writeln('Serving backend artifacts from ${apiRootDirectory.path}');
}

class _ServerConfiguration {
  const _ServerConfiguration({
    required this.bindAddress,
    required this.port,
    required this.apiRootPath,
  });

  final InternetAddress bindAddress;
  final int port;
  final String apiRootPath;

  factory _ServerConfiguration.fromEnvironment(List<String> arguments) {
    var bindHost = Platform.environment['LOCAL_BACKEND_HOST'] ?? '127.0.0.1';
    var port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
    var apiRootPath = _defaultApiRootPath();

    for (final argument in arguments) {
      if (argument.startsWith('--host=')) {
        bindHost = argument.substring('--host='.length);
      } else if (argument.startsWith('--port=')) {
        port = int.parse(argument.substring('--port='.length));
      } else if (argument.startsWith('--api-root=')) {
        apiRootPath = path.normalize(
          path.absolute(argument.substring('--api-root='.length)),
        );
      }
    }

    return _ServerConfiguration(
      bindAddress: InternetAddress(bindHost),
      port: port,
      apiRootPath: apiRootPath,
    );
  }

  static String _defaultApiRootPath() {
    final scriptDirectory = path.dirname(path.fromUri(Platform.script));
    return path.normalize(
      path.absolute(path.join(scriptDirectory, '..', '..', 'api')),
    );
  }
}
