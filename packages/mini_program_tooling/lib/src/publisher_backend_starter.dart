import 'publisher_backend/dependencies.dart';
import 'publisher_backend/lifecycle.dart';
import 'publisher_backend/models.dart';
import 'publisher_backend/urls.dart';
import 'publisher_backend/workspace.dart';

export 'publisher_backend/models.dart'
    show
        PublisherBackendClock,
        PublisherBackendDelay,
        PublisherBackendException,
        PublisherBackendHealthGetter,
        PublisherBackendProcessStarter,
        PublisherBackendRunResult,
        PublisherBackendScaffoldRequest,
        PublisherBackendScaffoldResult,
        PublisherBackendShellRunner,
        PublisherBackendState,
        PublisherBackendStatusResult,
        PublisherBackendStopResult,
        PublisherBackendUrlsResult,
        StartedPublisherBackendProcess;

/// Public compatibility facade for mock Publisher API workspace lifecycle.
class PublisherBackendStarter {
  const PublisherBackendStarter({
    PublisherBackendShellRunner shellRunner =
        defaultPublisherBackendShellRunner,
    PublisherBackendProcessStarter processStarter =
        defaultPublisherBackendProcessStarter,
    PublisherBackendHealthGetter healthGetter =
        defaultPublisherBackendHealthGetter,
    PublisherBackendClock clock = defaultPublisherBackendClock,
    PublisherBackendDelay delay = defaultPublisherBackendDelay,
  }) : _shellRunner = shellRunner,
       _processStarter = processStarter,
       _healthGetter = healthGetter,
       _clock = clock,
       _delay = delay;

  final PublisherBackendShellRunner _shellRunner;
  final PublisherBackendProcessStarter _processStarter;
  final PublisherBackendHealthGetter _healthGetter;
  final PublisherBackendClock _clock;
  final PublisherBackendDelay _delay;

  PublisherBackendDependencies get _dependencies =>
      PublisherBackendDependencies(
        shellRunner: _shellRunner,
        processStarter: _processStarter,
        healthGetter: _healthGetter,
        clock: _clock,
        delay: _delay,
      );

  Future<PublisherBackendScaffoldResult> scaffold(
    PublisherBackendScaffoldRequest request,
  ) => const PublisherBackendWorkspace().scaffold(request);

  Future<PublisherBackendRunResult> run({
    required String miniProgramRootPath,
    int port = 9090,
  }) => PublisherBackendLifecycle(
    _dependencies,
  ).run(miniProgramRootPath: miniProgramRootPath, port: port);

  Future<PublisherBackendStatusResult> status({
    required String miniProgramRootPath,
  }) => PublisherBackendLifecycle(
    _dependencies,
  ).status(miniProgramRootPath: miniProgramRootPath);

  Future<PublisherBackendStopResult> stop({
    required String miniProgramRootPath,
  }) => PublisherBackendLifecycle(
    _dependencies,
  ).stop(miniProgramRootPath: miniProgramRootPath);

  PublisherBackendUrlsResult urls({int port = 9090}) =>
      buildPublisherBackendUrls(port: port);
}
