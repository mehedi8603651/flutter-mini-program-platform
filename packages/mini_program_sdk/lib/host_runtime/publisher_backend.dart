part of '../mini_program_host.dart';

extension _MiniProgramHostPublisherBackend on _MiniProgramHostState {
  MiniProgramBackendConnector? _backendConnectorFor(
    LoadedMiniProgram loadedMiniProgram,
  ) {
    final contract = loadedMiniProgram.publisherBackendContract;
    if (contract == null) {
      return widget.backendConnector;
    }
    final source = widget.source;
    final policy = source is MiniProgramPublisherApiPolicyProvider
        ? (source as MiniProgramPublisherApiPolicyProvider)
              .publisherApiPolicyFor(contract.appId)
        : const MiniProgramPublisherApiPolicy();
    if (!policy.enabled) {
      return const DisabledMiniProgramBackendConnector();
    }
    final deliveryContext = source is MiniProgramDeliveryContextProvider
        ? (source as MiniProgramDeliveryContextProvider).deliveryContext
        : null;
    if (deliveryContext == null) {
      widget.logger.warn(
        'Publisher API was accepted, but the mini-program source does not '
        'provide delivery context for request headers.',
        context: <String, Object?>{'miniProgramId': contract.appId},
      );
      return null;
    }
    return EndpointRoutingMiniProgramBackendConnector(
      backends: <String, MiniProgramBackendEndpoint>{
        contract.appId: MiniProgramBackendEndpoint(
          baseUri: contract.backendBaseUri,
        ),
      },
      deliveryContext: deliveryContext,
    );
  }

  void _setActiveBackendConnector(MiniProgramBackendConnector? connector) {
    _disposeOwnedBackendConnector();
    _activeBackendConnector = connector;
    if (connector is DisposableMiniProgramBackendConnector &&
        !identical(connector, widget.backendConnector)) {
      _ownedBackendConnector = connector;
    }
  }

  void _disposeOwnedBackendConnector() {
    _ownedBackendConnector?.dispose();
    _ownedBackendConnector = null;
    _activeBackendConnector = null;
  }
}
