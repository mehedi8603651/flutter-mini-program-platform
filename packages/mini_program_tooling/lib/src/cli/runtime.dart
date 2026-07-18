import 'artifact_commands.dart';
import 'backend_commands.dart';
import 'command_imports.dart';
import 'context.dart';
import 'core_commands.dart';
import 'env_commands.dart';
import 'host_partner_commands.dart';
import 'json_output_helpers.dart';
import 'publisher_backend_commands.dart';
import 'usage_helpers.dart';
import 'workflow_commands.dart';

Future<int> runMiniprogramCli(
  CliContext context,
  List<String> arguments,
) async {
  if (arguments.isEmpty ||
      arguments.first == 'help' ||
      arguments.first == '--help' ||
      arguments.first == '-h') {
    context.stdoutSink.writeln(context.rootUsage());
    return 0;
  }

  try {
    switch (arguments.first) {
      case 'create':
        return await context.runCreateCommand(arguments.sublist(1));
      case 'capabilities':
        return context.runCapabilitiesCommand(arguments.sublist(1));
      case 'doctor':
        return await context.runDoctorCommand(arguments.sublist(1));
      case 'env':
        return await context.runEnvCommand(arguments.sublist(1));
      case 'build':
        return await context.runBuildCommand(arguments.sublist(1));
      case 'artifact':
        return await context.runArtifactCommand(arguments.sublist(1));
      case 'preview':
        return await context.runPreviewCommand(arguments.sublist(1));
      case 'validate':
        return await context.runValidateCommand(arguments.sublist(1));
      case 'publish':
        return await context.runPublishCommand(arguments.sublist(1));
      case 'access-key':
        throw const FormatException(
          'access-key commands were removed. Mini-program artifacts are '
          'public static files; use a publisher middle-server for runtime '
          'auth and business data.',
        );
      case 'cloud':
        throw const FormatException(
          'provider delivery commands were removed. Build portable '
          'artifacts with `miniprogram artifact build`, verify them, and '
          'host the artifacts directory on any static file host.',
        );
      case 'workflow':
        return await context.runWorkflowCommand(arguments.sublist(1));
      case 'partner':
        return await context.runPartnerCommand(arguments.sublist(1));
      case 'host':
        return await context.runHostCommand(arguments.sublist(1));
      case 'embed':
        return await context.runEmbedCommand(arguments.sublist(1));
      case 'artifact-host':
        return await context.runBackendCommand(
          arguments.sublist(1),
          commandName: 'artifact-host',
        );
      case 'backend':
        return await context.runBackendCommand(
          arguments.sublist(1),
          commandName: 'backend',
        );
      case 'publisher-backend':
        return await context.runPublisherBackendCommand(arguments.sublist(1));
      case 'publisher-api':
        return await context.runPublisherBackendCommand(
          arguments.sublist(1),
          commandName: 'publisher-api',
        );
      default:
        context.stderrSink.writeln('Unknown command: ${arguments.first}');
        context.stderrSink.writeln(context.rootUsage());
        return 64;
    }
  } on FormatException catch (error) {
    context.stderrSink.writeln(error.message);
    return 64;
  } on MiniProgramScaffoldException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on MiniProgramBuildException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on MiniProgramArtifactException catch (error) {
    context.stderrSink.writeln(error);
    if (error.details.isNotEmpty) {
      context.stderrSink.writeln(context.prettyJson(error.details));
    }
    return 1;
  } on MiniProgramPreviewException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on MiniProgramPublishException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on MiniProgramHostException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on MiniProgramHostCapabilityException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on MiniProgramPartnerHandoffException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on MiniProgramEmbeddingInitException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on MiniProgramPathResolutionException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on LocalCliStateException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on LocalBackendControlException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  } on PublisherBackendException catch (error) {
    context.stderrSink.writeln(error.message);
    return 1;
  }
}
