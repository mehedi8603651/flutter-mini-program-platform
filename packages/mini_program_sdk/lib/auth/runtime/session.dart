part of '../mini_program_auth.dart';

@immutable
class MiniProgramAuthSession {
  const MiniProgramAuthSession({
    required this.miniProgramId,
    required this.user,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAtUtc,
  });

  final String miniProgramId;
  final MiniProgramAuthUser user;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAtUtc;

  bool isExpired({
    DateTime? nowUtc,
    Duration skew = const Duration(seconds: 30),
  }) {
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    return !expiresAtUtc.toUtc().isAfter(now.add(skew));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'miniProgramId': miniProgramId,
    'user': user.toJson(),
    'idToken': idToken,
    'refreshToken': refreshToken,
    'expiresAtUtc': expiresAtUtc.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toBindingData() => <String, dynamic>{
    'miniProgramId': miniProgramId,
    'user': user.toBindingData(),
    'expiresAtUtc': expiresAtUtc.toUtc().toIso8601String(),
  };

  factory MiniProgramAuthSession.fromJson(Map<String, dynamic> json) {
    final miniProgramId = json['miniProgramId'];
    final user = json['user'];
    final idToken = json['idToken'];
    final refreshToken = json['refreshToken'];
    final expiresAtUtc = json['expiresAtUtc'];
    if (miniProgramId is! String || miniProgramId.trim().isEmpty) {
      throw const FormatException('Auth session requires a miniProgramId.');
    }
    if (user is! Map) {
      throw const FormatException('Auth session requires a user object.');
    }
    if (idToken is! String || idToken.trim().isEmpty) {
      throw const FormatException('Auth session requires an idToken.');
    }
    if (refreshToken is! String || refreshToken.trim().isEmpty) {
      throw const FormatException('Auth session requires a refreshToken.');
    }
    if (expiresAtUtc is! String || expiresAtUtc.trim().isEmpty) {
      throw const FormatException('Auth session requires expiresAtUtc.');
    }
    final parsedExpiry = DateTime.tryParse(expiresAtUtc);
    if (parsedExpiry == null) {
      throw const FormatException('Auth session expiresAtUtc is invalid.');
    }
    return MiniProgramAuthSession(
      miniProgramId: miniProgramId.trim(),
      user: MiniProgramAuthUser.fromJson(Map<String, dynamic>.from(user)),
      idToken: idToken.trim(),
      refreshToken: refreshToken.trim(),
      expiresAtUtc: parsedExpiry.toUtc(),
    );
  }

  static MiniProgramAuthSession fromBackendData({
    required String miniProgramId,
    required Map<String, dynamic> data,
    required DateTime nowUtc,
  }) {
    final authenticated = data['authenticated'];
    if (authenticated == false) {
      throw const FormatException('Auth response is not authenticated.');
    }
    final rawUser = data['user'];
    final idToken = data['idToken'];
    final refreshToken = data['refreshToken'];
    if (rawUser is! Map) {
      throw const FormatException('Auth response requires a user object.');
    }
    if (idToken is! String || idToken.trim().isEmpty) {
      throw const FormatException('Auth response requires an idToken.');
    }
    if (refreshToken is! String || refreshToken.trim().isEmpty) {
      throw const FormatException('Auth response requires a refreshToken.');
    }

    final expiresAtUtc = _parseAuthExpiry(data, nowUtc);
    return MiniProgramAuthSession(
      miniProgramId: miniProgramId.trim(),
      user: MiniProgramAuthUser.fromJson(Map<String, dynamic>.from(rawUser)),
      idToken: idToken.trim(),
      refreshToken: refreshToken.trim(),
      expiresAtUtc: expiresAtUtc,
    );
  }
}

DateTime _parseAuthExpiry(Map<String, dynamic> data, DateTime nowUtc) {
  final expiresAtUtc = data['expiresAtUtc'];
  if (expiresAtUtc is String && expiresAtUtc.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(expiresAtUtc);
    if (parsed != null) {
      return parsed.toUtc();
    }
  }

  final expiresIn = data['expiresIn'];
  final seconds = switch (expiresIn) {
    int value => value,
    String value => int.tryParse(value),
    _ => null,
  };
  if (seconds == null || seconds <= 0) {
    throw const FormatException(
      'Auth response requires expiresIn or expiresAtUtc.',
    );
  }
  return nowUtc.toUtc().add(Duration(seconds: seconds));
}
