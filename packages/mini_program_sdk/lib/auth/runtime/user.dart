part of '../mini_program_auth.dart';

@immutable
class MiniProgramAuthUser {
  const MiniProgramAuthUser({required this.uid, this.email});

  final String uid;
  final String? email;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    if (email != null) 'email': email,
  };

  Map<String, dynamic> toBindingData() => toJson();

  factory MiniProgramAuthUser.fromJson(Map<String, dynamic> json) {
    final uid = json['uid'];
    if (uid is! String || uid.trim().isEmpty) {
      throw const FormatException('Auth user requires a non-empty uid.');
    }
    final email = json['email'];
    if (email != null && email is! String) {
      throw const FormatException('Auth user email must be a string.');
    }
    return MiniProgramAuthUser(
      uid: uid.trim(),
      email: email == null || email.trim().isEmpty ? null : email.trim(),
    );
  }
}
