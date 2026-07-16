part of '../mini_program_auth.dart';

enum MiniProgramAuthStatus {
  unknown,
  restoring,
  signedOut,
  signingIn,
  signingUp,
  refreshing,
  signedIn,
  error,
}

@immutable
class MiniProgramAuthSnapshot {
  const MiniProgramAuthSnapshot({
    required this.status,
    this.user,
    this.message,
    this.errorCode,
    this.expiresAtUtc,
  });

  const MiniProgramAuthSnapshot.unknown()
    : status = MiniProgramAuthStatus.unknown,
      user = null,
      message = null,
      errorCode = null,
      expiresAtUtc = null;

  const MiniProgramAuthSnapshot.signedOut({this.message})
    : status = MiniProgramAuthStatus.signedOut,
      user = null,
      errorCode = null,
      expiresAtUtc = null;

  MiniProgramAuthSnapshot.fromSession(MiniProgramAuthSession session)
    : status = MiniProgramAuthStatus.signedIn,
      user = session.user,
      message = null,
      errorCode = null,
      expiresAtUtc = session.expiresAtUtc;

  final MiniProgramAuthStatus status;
  final MiniProgramAuthUser? user;
  final String? message;
  final String? errorCode;
  final DateTime? expiresAtUtc;

  bool get authenticated => status == MiniProgramAuthStatus.signedIn;
  bool get loading =>
      status == MiniProgramAuthStatus.restoring ||
      status == MiniProgramAuthStatus.signingIn ||
      status == MiniProgramAuthStatus.signingUp ||
      status == MiniProgramAuthStatus.refreshing;
  bool get signedOut => status == MiniProgramAuthStatus.signedOut;
  bool get hasError => status == MiniProgramAuthStatus.error;

  Map<String, dynamic> toBindingData() => <String, dynamic>{
    'status': status.name,
    'authenticated': authenticated,
    'loading': loading,
    'signedOut': signedOut,
    'error': hasError,
    if (user != null) 'user': user!.toBindingData(),
    if (message != null) 'message': message,
    if (errorCode != null) 'errorCode': errorCode,
    if (expiresAtUtc != null)
      'expiresAtUtc': expiresAtUtc!.toUtc().toIso8601String(),
  };
}
