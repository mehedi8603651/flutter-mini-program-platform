class MiniProgramPublishException implements Exception {
  const MiniProgramPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}
