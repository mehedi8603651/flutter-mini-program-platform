class HostEndpointRecord {
  const HostEndpointRecord({required this.apiBaseUri});

  final String apiBaseUri;
}

class HostRegistryRecord {
  const HostRegistryRecord({
    required this.appId,
    required this.title,
    required this.constantName,
  });

  final String appId;
  final String title;
  final String constantName;
}
