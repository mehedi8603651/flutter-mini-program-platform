import 'support.dart';

extension CliWorkflowCommands on CliContext {
  StringSink get _stdout => stdoutSink;
  StringSink get _stderr => stderrSink;
  DeliveryRepositoryValidator get _validator => dependencies.validator;
  LocalBackendController get _backendController =>
      dependencies.backendController;
  LocalCliStateStore get _stateStore => dependencies.stateStore;

  Future<int> runWorkflowCommand(List<String> arguments) =>
      _runWorkflow(arguments);

  Future<int> _runWorkflow(List<String> arguments) async {
    if (isGroupHelpRequest(arguments)) {
      _stdout.writeln(workflowUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(workflowUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'status':
        return _runWorkflowStatus(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown workflow command: ${arguments.first}');
        _stderr.writeln(workflowUsage());
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
        workspacePath: results.option('workspace') ?? currentWorkingDirectory(),
        environmentName: results.option('env'),
        remote: results.flag('remote'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(prettyJson(result.json));
    } else {
      _stdout.writeln(formatWorkflowStatusResult(result));
    }
    return 0;
  }
}
