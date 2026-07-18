import 'dart:io';

import 'package:path/path.dart' as p;

String normalizeAbsolutePath(String path) => p.normalize(p.absolute(path));

String normalizeWorkingDirectory(String? path) =>
    normalizeAbsolutePath(path ?? Directory.current.path);
