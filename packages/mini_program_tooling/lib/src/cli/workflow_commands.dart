part of '../miniprogram_cli.dart';

extension _MiniprogramCliWorkflowCommands on MiniprogramCli {
  Future<int> _runWorkflow(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_workflowUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_workflowUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'status':
        return _runWorkflowStatus(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown workflow command: ${arguments.first}');
        _stderr.writeln(_workflowUsage());
        return 64;
    }
  }

  Future<int> _runWorkflowStatus(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addFlag(
        'remote',
        negatable: false,
        help:
            'Compatibility flag. Provider remote checks were removed from the MVP flow.',
      )
      ..addOption(
        'workspace',
        help:
            'Mini-program or Flutter host app workspace. Defaults to the current directory.',
      )
      ..addOption('env', help: 'Ignored legacy provider environment override.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram workflow status [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'workflow status does not accept positional arguments.',
      );
    }

    final controller = MiniProgramWorkflowStatusController(
      stateStore: _stateStore,
      validator: _validator,
      backendController: _backendController,
    );
    final result = await controller.inspect(
      MiniProgramWorkflowStatusRequest(
        workspacePath:
            results.option('workspace') ?? _currentWorkingDirectory(),
        environmentName: results.option('env'),
        remote: results.flag('remote'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(result.json));
    } else {
      _stdout.writeln(_formatWorkflowStatusResult(result));
    }
    return 0;
  }
}
