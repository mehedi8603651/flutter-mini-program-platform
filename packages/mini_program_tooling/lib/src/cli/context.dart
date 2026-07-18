import 'command_imports.dart';

class CliDependencies {
  const CliDependencies({
    required this.scaffolder,
    required this.builder,
    required this.artifactBuilder,
    required this.artifactVerifier,
    required this.validator,
    required this.publisher,
    required this.embeddingInitializer,
    required this.backendController,
    required this.backendInitializer,
    required this.previewController,
    required this.staticPublisher,
    required this.hostController,
    required this.hostCapabilityInstaller,
    required this.partnerHandoffController,
    required this.doctor,
    required this.stateStore,
    required this.pathResolver,
    required this.publisherBackendContractController,
    required this.publisherBackendStarter,
  });

  final MiniProgramScaffolder scaffolder;
  final MiniProgramBuilder builder;
  final MiniProgramArtifactBuilder artifactBuilder;
  final MiniProgramArtifactVerifier artifactVerifier;
  final DeliveryRepositoryValidator validator;
  final MiniProgramPublisher publisher;
  final MiniProgramEmbeddingInitializer embeddingInitializer;
  final LocalBackendController backendController;
  final LocalBackendInitializer backendInitializer;
  final MiniProgramPreviewController previewController;
  final MiniProgramStaticPublisher staticPublisher;
  final MiniProgramHostController hostController;
  final MiniProgramHostCapabilityInstaller hostCapabilityInstaller;
  final MiniProgramPartnerHandoffController partnerHandoffController;
  final MiniprogramDoctor doctor;
  final LocalCliStateStore stateStore;
  final MiniProgramPathResolver pathResolver;
  final PublisherBackendContractController publisherBackendContractController;
  final PublisherBackendStarter publisherBackendStarter;
}

class CliContext {
  const CliContext({
    required this.dependencies,
    required this.stdoutSink,
    required this.stderrSink,
    required this.workingDirectory,
  });

  final CliDependencies dependencies;
  final StringSink stdoutSink;
  final StringSink stderrSink;
  final String? workingDirectory;
}
