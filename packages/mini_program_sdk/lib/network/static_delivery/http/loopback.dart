part of '../../http_mini_program_source.dart';

extension _HttpMiniProgramSourceLoopback on HttpMiniProgramSource {
  List<Uri> _candidateUris(Uri primaryUri) {
    if (!enableLocalLoopbackFallback || primaryUri.scheme != 'http') {
      return <Uri>[primaryUri];
    }

    final hosts = <String>[primaryUri.host];
    if (primaryUri.host == '10.0.2.2') {
      hosts.add('127.0.0.1');
    } else if (primaryUri.host == '127.0.0.1' ||
        primaryUri.host == 'localhost') {
      hosts.add('10.0.2.2');
    }

    return hosts
        .toSet()
        .map(
          (host) => host == primaryUri.host
              ? primaryUri
              : primaryUri.replace(host: host),
        )
        .toList();
  }
}

class _TransportSourceException implements Exception {
  const _TransportSourceException(this.sourceException);

  final MiniProgramSourceException sourceException;
}
