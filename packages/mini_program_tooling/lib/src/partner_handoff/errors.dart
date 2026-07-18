class MiniProgramPartnerHandoffException implements Exception {
  const MiniProgramPartnerHandoffException(this.message);

  final String message;

  @override
  String toString() => message;
}
