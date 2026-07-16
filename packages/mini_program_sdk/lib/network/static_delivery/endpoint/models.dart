part of '../../mini_program_endpoint.dart';

typedef MiniProgramEndpointSourceFactory =
    MiniProgramSource Function({
      required String appId,
      required MiniProgramEndpoint endpoint,
      required MiniProgramDeliveryContext deliveryContext,
    });

/// A remote mini-program delivery endpoint registered by a host app.
///
/// Host UI should open mini-programs by `appId`; endpoint configuration owns
/// where that app's static artifacts are delivered from.
@immutable
class MiniProgramEndpoint {
  const MiniProgramEndpoint({
    required this.apiBaseUri,
    this.headers = const <String, String>{},
    this.requestTimeout = const Duration(seconds: 5),
    this.enableLocalLoopbackFallback = true,
    this.cachePolicy = const MiniProgramCachePolicy(),
    this.liveStatePolicy = const MiniProgramLiveStatePolicy(),
    this.publisherApiPolicy = const MiniProgramPublisherApiPolicy(),
    this.locationPolicy = const MiniProgramLocationPolicy(),
  });

  /// Creates a public/static mini-program endpoint.
  ///
  /// Static mini-program artifacts are public UI bundles. Runtime business
  /// data belongs behind an optional Publisher API/middle-server connector.
  const MiniProgramEndpoint.public({
    required this.apiBaseUri,
    this.headers = const <String, String>{},
    this.requestTimeout = const Duration(seconds: 5),
    this.enableLocalLoopbackFallback = true,
    this.cachePolicy = const MiniProgramCachePolicy(),
    this.liveStatePolicy = const MiniProgramLiveStatePolicy(),
    this.publisherApiPolicy = const MiniProgramPublisherApiPolicy(),
    this.locationPolicy = const MiniProgramLocationPolicy(),
  });

  final Uri apiBaseUri;
  final Map<String, String> headers;
  final Duration requestTimeout;
  final bool enableLocalLoopbackFallback;
  final MiniProgramCachePolicy cachePolicy;
  final MiniProgramLiveStatePolicy liveStatePolicy;
  final MiniProgramPublisherApiPolicy publisherApiPolicy;
  final MiniProgramLocationPolicy locationPolicy;
}
