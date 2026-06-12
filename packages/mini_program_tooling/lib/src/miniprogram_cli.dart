import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as p;

import 'mini_program_cloud_publisher.dart';
import 'mini_program_cloud_controller.dart';
import 'delivery_validation.dart';
import 'delivery_validator.dart';
import 'local_backend_controller.dart';
import 'local_backend_initializer.dart';
import 'local_cli_state.dart';
import 'mini_program_builder.dart';
import 'mini_program_host_controller.dart';
import 'miniprogram_doctor.dart';
import 'mini_program_embedding_initializer.dart';
import 'mini_program_firebase_hosting_publisher.dart';
import 'mini_program_path_resolver.dart';
import 'mini_program_partner_handoff.dart';
import 'mini_program_preview_controller.dart';
import 'mini_program_preview_server.dart';
import 'mini_program_publisher.dart';
import 'mini_program_scaffolder.dart';
import 'mini_program_static_publisher.dart';
import 'mini_program_workflow_status.dart';
import 'publisher_backend_contract_controller.dart';
import 'publisher_backend_starter.dart';

part 'cli/miniprogram_cli_constants.dart';
part 'cli/core_commands.dart';
part 'cli/cloud_access_commands.dart';
part 'cli/workflow_commands.dart';
part 'cli/host_partner_commands.dart';
part 'cli/env_commands.dart';
part 'cli/backend_commands.dart';
part 'cli/publisher_backend_commands.dart';
part 'cli/publisher_backend_contract_commands.dart';
part 'cli/firebase_host_diagnostics.dart';
part 'cli/shared_helpers.dart';
part 'cli/usage_helpers.dart';
part 'cli/json_output_helpers.dart';
part 'cli/result_formatters.dart';
part 'cli/publisher_backend_output_helpers.dart';
part 'cli/private_models.dart';

class MiniprogramCli {
  MiniprogramCli({
    MiniProgramScaffolder scaffolder = const MiniProgramScaffolder(),
    MiniProgramBuilder builder = const MiniProgramBuilder(),
    DeliveryRepositoryValidator validator = const DeliveryRepositoryValidator(),
    MiniProgramPublisher publisher = const MiniProgramPublisher(),
    MiniProgramEmbeddingInitializer embeddingInitializer =
        const MiniProgramEmbeddingInitializer(),
    LocalBackendController backendController = const LocalBackendController(),
    LocalBackendInitializer backendInitializer =
        const LocalBackendInitializer(),
    MiniProgramPreviewController previewController =
        const MiniProgramPreviewController(),
    MiniProgramCloudPublisher cloudPublisher =
        const MiniProgramCloudPublisher(),
    MiniProgramStaticPublisher staticPublisher =
        const MiniProgramStaticPublisher(),
    MiniProgramFirebaseHostingPublisher firebaseHostingPublisher =
        const MiniProgramFirebaseHostingPublisher(),
    MiniProgramCloudController? cloudController,
    MiniProgramHostController? hostController,
    MiniProgramPartnerHandoffController partnerHandoffController =
        const MiniProgramPartnerHandoffController(),
    MiniprogramDoctor doctor = const MiniprogramDoctor(),
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    MiniProgramPathResolver pathResolver = const MiniProgramPathResolver(),
    PublisherBackendContractController publisherBackendContractController =
        const PublisherBackendContractController(),
    PublisherBackendStarter publisherBackendStarter =
        const PublisherBackendStarter(),
    StringSink? stdoutSink,
    StringSink? stderrSink,
    String? workingDirectory,
  }) : _scaffolder = scaffolder,
       _builder = builder,
       _validator = validator,
       _publisher = publisher,
       _embeddingInitializer = embeddingInitializer,
       _backendController = backendController,
       _backendInitializer = backendInitializer,
       _previewController = previewController,
       _cloudPublisher = cloudPublisher,
       _staticPublisher = staticPublisher,
       _firebaseHostingPublisher = firebaseHostingPublisher,
       _cloudController = cloudController ?? MiniProgramCloudController(),
       _hostController = hostController ?? MiniProgramHostController(),
       _partnerHandoffController = partnerHandoffController,
       _doctor = doctor,
       _stateStore = stateStore,
       _pathResolver = pathResolver,
       _publisherBackendContractController = publisherBackendContractController,
       _publisherBackendStarter = publisherBackendStarter,
       _stdout = stdoutSink ?? stdout,
       _stderr = stderrSink ?? stderr,
       _workingDirectory = workingDirectory;

  final MiniProgramScaffolder _scaffolder;
  final MiniProgramBuilder _builder;
  final DeliveryRepositoryValidator _validator;
  final MiniProgramPublisher _publisher;
  final MiniProgramEmbeddingInitializer _embeddingInitializer;
  final LocalBackendController _backendController;
  final LocalBackendInitializer _backendInitializer;
  final MiniProgramPreviewController _previewController;
  final MiniProgramCloudPublisher _cloudPublisher;
  final MiniProgramStaticPublisher _staticPublisher;
  final MiniProgramFirebaseHostingPublisher _firebaseHostingPublisher;
  final MiniProgramCloudController _cloudController;
  final MiniProgramHostController _hostController;
  final MiniProgramPartnerHandoffController _partnerHandoffController;
  final MiniprogramDoctor _doctor;
  final LocalCliStateStore _stateStore;
  final MiniProgramPathResolver _pathResolver;
  final PublisherBackendContractController _publisherBackendContractController;
  final PublisherBackendStarter _publisherBackendStarter;
  final StringSink _stdout;
  final StringSink _stderr;
  final String? _workingDirectory;

  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty ||
        arguments.first == 'help' ||
        arguments.first == '--help' ||
        arguments.first == '-h') {
      _stdout.writeln(_rootUsage());
      return 0;
    }

    try {
      switch (arguments.first) {
        case 'create':
          return await _runCreate(arguments.sublist(1));
        case 'capabilities':
          return _runCapabilities(arguments.sublist(1));
        case 'doctor':
          return await _runDoctor(arguments.sublist(1));
        case 'env':
          return await _runEnv(arguments.sublist(1));
        case 'build':
          return await _runBuild(arguments.sublist(1));
        case 'preview':
          return await _runPreview(arguments.sublist(1));
        case 'validate':
          return await _runValidate(arguments.sublist(1));
        case 'publish':
          return await _runPublish(arguments.sublist(1));
        case 'access-key':
          return await _runAccessKey(arguments.sublist(1));
        case 'cloud':
          return await _runCloud(arguments.sublist(1));
        case 'workflow':
          return await _runWorkflow(arguments.sublist(1));
        case 'partner':
          return await _runPartner(arguments.sublist(1));
        case 'host':
          return await _runHost(arguments.sublist(1));
        case 'embed':
          return await _runEmbed(arguments.sublist(1));
        case 'backend':
          return await _runBackend(arguments.sublist(1));
        case 'publisher-backend':
          return await _runPublisherBackend(arguments.sublist(1));
        case 'publisher-api':
          return await _runPublisherBackend(
            arguments.sublist(1),
            commandName: 'publisher-api',
          );
        default:
          _stderr.writeln('Unknown command: ${arguments.first}');
          _stderr.writeln(_rootUsage());
          return 64;
      }
    } on FormatException catch (error) {
      _stderr.writeln(error.message);
      return 64;
    } on MiniProgramScaffoldException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramBuildException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramPreviewException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramPublishException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramCloudException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramHostException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramPartnerHandoffException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramEmbeddingInitException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramPathResolutionException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on LocalCliStateException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on LocalBackendControlException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on PublisherBackendException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    }
  }
}
