import 'dart:convert';
import 'dart:io';

import 'dependencies.dart';

class PublisherBackendProcessControl {
  const PublisherBackendProcessControl(this.dependencies);

  final PublisherBackendDependencies dependencies;

  Future<bool> isAlive(int pid) async {
    if (Platform.isWindows) {
      final result = await dependencies.shellRunner('tasklist', <String>[
        '/FI',
        'PID eq $pid',
        '/FO',
        'CSV',
        '/NH',
      ]);
      if (result.exitCode != 0) {
        return false;
      }
      final output = '${result.stdout}'.trim();
      return output.isNotEmpty &&
          !output.toLowerCase().contains('no tasks are running');
    }
    final result = await dependencies.shellRunner('ps', <String>['-p', '$pid']);
    if (result.exitCode != 0) {
      return false;
    }
    return const LineSplitter().convert('${result.stdout}'.trim()).length > 1;
  }

  Future<ProcessResult> terminate(int pid) {
    if (Platform.isWindows) {
      return dependencies.shellRunner('taskkill', <String>[
        '/PID',
        '$pid',
        '/T',
        '/F',
      ]);
    }
    return dependencies.shellRunner('kill', <String>['$pid']);
  }
}
