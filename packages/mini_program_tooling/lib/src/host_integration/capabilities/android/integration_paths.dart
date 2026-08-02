import 'dart:io';

import 'package:path/path.dart' as p;

class AndroidNativeIntegrationPaths {
  AndroidNativeIntegrationPaths(this.mainActivityFile)
    : packageRoot = mainActivityFile.parent,
      integrationRoot = Directory(
        p.join(mainActivityFile.parent.path, 'mini_program'),
      ),
      generatedRoot = Directory(
        p.join(mainActivityFile.parent.path, 'mini_program', 'generated'),
      );

  final File mainActivityFile;
  final Directory packageRoot;
  final Directory integrationRoot;
  final Directory generatedRoot;

  File get setupFile =>
      File(p.join(generatedRoot.path, 'MiniProgramNativeSetup.kt'));

  File get ownershipFile => File(p.join(integrationRoot.path, 'README.md'));

  File generatedFile(String feature, String fileName) =>
      File(p.join(generatedRoot.path, feature, fileName));

  File legacyFile(String fileName) => File(p.join(packageRoot.path, fileName));
}

const String androidNativeIntegrationReadme =
    '''# Mini-Program Android Integration

The `generated/` directory is owned by `mini_program_tooling` and may be
updated by `miniprogram host capability init` commands. Do not place host
application code in this directory.

Keep host-owned native features beside `MainActivity.kt` or in a separate
application package. `MainActivity.kt` contains one stable call to
`MiniProgramNativeSetup.register(...)`.
''';
