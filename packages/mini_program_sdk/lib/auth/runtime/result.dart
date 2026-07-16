part of '../mini_program_auth.dart';

@immutable
class MiniProgramAuthResult {
  const MiniProgramAuthResult({
    required this.success,
    required this.snapshot,
    this.message,
    this.errorCode,
    this.statusCode,
  });

  final bool success;
  final MiniProgramAuthSnapshot snapshot;
  final String? message;
  final String? errorCode;
  final int? statusCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'success': success,
    'authenticated': snapshot.authenticated,
    'status': snapshot.status.name,
    if (message != null) 'message': message,
    if (errorCode != null) 'errorCode': errorCode,
    if (statusCode != null) 'statusCode': statusCode,
    'auth': snapshot.toBindingData(),
  };
}
