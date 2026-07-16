part of '../mini_program_auth.dart';

typedef MiniProgramAuthClock = DateTime Function();

abstract final class MiniProgramAuthHttpHeaders {
  static const String authorization = 'authorization';
}

@immutable
class MiniProgramAuthBackendPaths {
  const MiniProgramAuthBackendPaths({
    this.emailSignIn = 'auth/email/sign-in',
    this.emailSignUp = 'auth/email/sign-up',
    this.refresh = 'auth/refresh',
    this.signOut = 'auth/sign-out',
    this.session = 'auth/session',
  });

  final String emailSignIn;
  final String emailSignUp;
  final String refresh;
  final String signOut;
  final String session;
}
