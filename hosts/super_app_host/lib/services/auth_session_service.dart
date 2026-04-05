import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

enum LocalAuthSessionSeedMode { authenticated, signedOut, expired, blocked }

@immutable
class HostSession {
  const HostSession({
    required this.userId,
    required this.accessToken,
    required this.displayName,
    this.tenantId,
    this.expiresAt,
  });

  final String userId;
  final String accessToken;
  final String displayName;
  final String? tenantId;
  final DateTime? expiresAt;
}

enum HostAuthStateStatus { authenticated, signedOut, expired }

@immutable
class HostAuthState {
  const HostAuthState._({required this.status, this.session, this.message});

  const HostAuthState.authenticated(HostSession session)
    : this._(status: HostAuthStateStatus.authenticated, session: session);

  const HostAuthState.signedOut({String? message})
    : this._(status: HostAuthStateStatus.signedOut, message: message);

  const HostAuthState.expired({HostSession? session, String? message})
    : this._(
        status: HostAuthStateStatus.expired,
        session: session,
        message: message,
      );

  final HostAuthStateStatus status;
  final HostSession? session;
  final String? message;

  bool get isAuthenticated => status == HostAuthStateStatus.authenticated;
}

class AuthSessionException implements Exception {
  const AuthSessionException({
    required this.errorCode,
    required this.message,
    this.details = const <String, dynamic>{},
  });

  final String errorCode;
  final String message;
  final Map<String, dynamic> details;

  @override
  String toString() => 'AuthSessionException($errorCode, $message)';
}

abstract interface class AuthSessionService {
  ValueListenable<HostAuthState> get stateListenable;

  Future<HostSession> getCurrentSession();
}

class LocalAuthSessionService implements AuthSessionService {
  LocalAuthSessionService.authenticated({required HostSession session})
    : _state = ValueNotifier<HostAuthState>(
        HostAuthState.authenticated(session),
      );

  LocalAuthSessionService.signedOut({String? message})
    : _state = ValueNotifier<HostAuthState>(
        HostAuthState.signedOut(
          message: message ?? 'No signed-in host session is available.',
        ),
      );

  LocalAuthSessionService.expired({
    required HostSession session,
    String? message,
  }) : _state = ValueNotifier<HostAuthState>(
         HostAuthState.expired(
           session: session,
           message: message ?? 'The host session has expired.',
         ),
       );

  factory LocalAuthSessionService.seeded({
    required String userId,
    required String accessToken,
    required String displayName,
    String? tenantId,
    LocalAuthSessionSeedMode mode = LocalAuthSessionSeedMode.authenticated,
  }) {
    switch (mode) {
      case LocalAuthSessionSeedMode.signedOut:
        return LocalAuthSessionService.signedOut();
      case LocalAuthSessionSeedMode.expired:
        return LocalAuthSessionService.expired(
          session: HostSession(
            userId: userId,
            accessToken: 'expired-$accessToken',
            displayName: displayName,
            tenantId: tenantId,
            expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        );
      case LocalAuthSessionSeedMode.blocked:
        return LocalAuthSessionService.authenticated(
          session: HostSession(
            userId: 'blocked_$userId',
            accessToken: accessToken,
            displayName: displayName,
            tenantId: tenantId,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
      case LocalAuthSessionSeedMode.authenticated:
        return LocalAuthSessionService.authenticated(
          session: HostSession(
            userId: userId,
            accessToken: accessToken,
            displayName: displayName,
            tenantId: tenantId,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
    }
  }

  final ValueNotifier<HostAuthState> _state;

  @override
  ValueListenable<HostAuthState> get stateListenable => _state;

  @override
  Future<HostSession> getCurrentSession() async {
    final state = _state.value;
    switch (state.status) {
      case HostAuthStateStatus.signedOut:
        throw AuthSessionException(
          errorCode: MiniProgramErrorCodes.secureApiSessionMissing,
          message: state.message ?? 'No signed-in host session is available.',
          details: const <String, dynamic>{'authState': 'signed_out'},
        );
      case HostAuthStateStatus.expired:
        throw AuthSessionException(
          errorCode: MiniProgramErrorCodes.secureApiSessionExpired,
          message: state.message ?? 'The host session has expired.',
          details: const <String, dynamic>{'authState': 'expired'},
        );
      case HostAuthStateStatus.authenticated:
        final session = state.session!;
        final expiresAt = session.expiresAt;
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          _state.value = HostAuthState.expired(
            session: session,
            message: 'The host session expired before the secure API call.',
          );
          throw AuthSessionException(
            errorCode: MiniProgramErrorCodes.secureApiSessionExpired,
            message: 'The host session expired before the secure API call.',
            details: const <String, dynamic>{'authState': 'expired'},
          );
        }
        return session;
    }
  }

  void replaceSession(HostSession session) {
    _state.value = HostAuthState.authenticated(session);
  }

  void signOut({String? message}) {
    _state.value = HostAuthState.signedOut(
      message: message ?? 'The host session was signed out locally.',
    );
  }

  void expireSession({String? message}) {
    _state.value = HostAuthState.expired(
      session: _state.value.session,
      message: message ?? 'The host session expired locally.',
    );
  }
}
