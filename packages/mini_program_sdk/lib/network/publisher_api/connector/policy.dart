part of '../../mini_program_backend_connector.dart';

/// Host-owned permission for using an artifact-declared Publisher API.
@immutable
class MiniProgramPublisherApiPolicy {
  const MiniProgramPublisherApiPolicy({this.enabled = false});

  final bool enabled;
}

/// Optional source capability that supplies accepted Publisher API policy.
abstract interface class MiniProgramPublisherApiPolicyProvider {
  MiniProgramPublisherApiPolicy publisherApiPolicyFor(String miniProgramId);
}
