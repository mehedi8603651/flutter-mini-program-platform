import 'cli/command_imports.dart';
import 'cli/context.dart';
import 'cli/runtime.dart';

class MiniprogramCli {
  MiniprogramCli({
    MiniProgramScaffolder scaffolder = const MiniProgramScaffolder(),
    MiniProgramBuilder builder = const MiniProgramBuilder(),
    MiniProgramArtifactBuilder artifactBuilder =
        const MiniProgramArtifactBuilder(),
    MiniProgramArtifactVerifier artifactVerifier =
        const MiniProgramArtifactVerifier(),
    DeliveryRepositoryValidator validator = const DeliveryRepositoryValidator(),
    MiniProgramPublisher publisher = const MiniProgramPublisher(),
    MiniProgramEmbeddingInitializer embeddingInitializer =
        const MiniProgramEmbeddingInitializer(),
    LocalBackendController backendController = const LocalBackendController(),
    LocalBackendInitializer backendInitializer =
        const LocalBackendInitializer(),
    MiniProgramPreviewController previewController =
        const MiniProgramPreviewController(),
    MiniProgramStaticPublisher staticPublisher =
        const MiniProgramStaticPublisher(),
    MiniProgramHostController? hostController,
    MiniProgramHostCapabilityInstaller hostCapabilityInstaller =
        const MiniProgramHostCapabilityInstaller(),
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
  }) : _context = CliContext(
         dependencies: CliDependencies(
           scaffolder: scaffolder,
           builder: builder,
           artifactBuilder: artifactBuilder,
           artifactVerifier: artifactVerifier,
           validator: validator,
           publisher: publisher,
           embeddingInitializer: embeddingInitializer,
           backendController: backendController,
           backendInitializer: backendInitializer,
           previewController: previewController,
           staticPublisher: staticPublisher,
           hostController: hostController ?? MiniProgramHostController(),
           hostCapabilityInstaller: hostCapabilityInstaller,
           partnerHandoffController: partnerHandoffController,
           doctor: doctor,
           stateStore: stateStore,
           pathResolver: pathResolver,
           publisherBackendContractController:
               publisherBackendContractController,
           publisherBackendStarter: publisherBackendStarter,
         ),
         stdoutSink: stdoutSink ?? stdout,
         stderrSink: stderrSink ?? stderr,
         workingDirectory: workingDirectory,
       );

  final CliContext _context;

  Future<int> run(List<String> arguments) =>
      runMiniprogramCli(_context, arguments);
}
