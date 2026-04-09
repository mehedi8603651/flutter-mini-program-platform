import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await MiniprogramCli().run(arguments);
}
