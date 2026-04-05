import 'package:flutter/foundation.dart';

@immutable
class HostSession {
  const HostSession({
    required this.userId,
    required this.accessToken,
    this.tenantId,
  });

  final String userId;
  final String accessToken;
  final String? tenantId;
}

abstract interface class AuthSessionService {
  Future<HostSession> getCurrentSession();
}

class DemoAuthSessionService implements AuthSessionService {
  const DemoAuthSessionService({this.tenantId});

  final String? tenantId;

  @override
  Future<HostSession> getCurrentSession() async {
    return HostSession(
      userId: 'partner_demo_user',
      accessToken: 'partner-demo-access-token',
      tenantId: tenantId,
    );
  }
}
