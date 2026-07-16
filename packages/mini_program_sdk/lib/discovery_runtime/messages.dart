part of '../mini_program_discovery.dart';

extension _MiniProgramDiscoveryMessages on MiniProgramDiscoveryResolver {
  String _unavailableMessage(
    MiniProgramDiscoverySourceKind sourceKind,
    MiniProgramSourceException? sourceException,
  ) {
    if (sourceKind == MiniProgramDiscoverySourceKind.bundled) {
      return sourceException?.message ??
          'Bundled mini-program assets could not be loaded.';
    }

    final errorCode = sourceException?.errorCode;
    if (errorCode == MiniProgramErrorCodes.backendUnreachable ||
        errorCode == MiniProgramErrorCodes.backendTimeout) {
      return 'No valid offline copy is available.';
    }

    return sourceException?.message ??
        'Mini-program availability could not be determined.';
  }
}
