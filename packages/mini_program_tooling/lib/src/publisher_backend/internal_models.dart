part of '../publisher_backend_starter.dart';

class _PublisherBackendHealth {
  const _PublisherBackendHealth({
    required this.healthy,
    this.statusCode,
    this.error,
  });

  final bool healthy;
  final int? statusCode;
  final String? error;
}
