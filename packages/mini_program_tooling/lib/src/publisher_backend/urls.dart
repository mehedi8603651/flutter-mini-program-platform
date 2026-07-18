import 'models.dart';

PublisherBackendUrlsResult buildPublisherBackendUrls({int port = 9090}) {
  if (port <= 0 || port > 65535) {
    throw const PublisherBackendException(
      'publisher-backend urls --port must be 1-65535.',
    );
  }
  return PublisherBackendUrlsResult(port: port);
}
