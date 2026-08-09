/// Inert acknowledgement returned after the host opens its system share UI.
///
/// Android does not report whether the user completed a share, so this model
/// deliberately reports only that the chooser was opened.
class MiniProgramShareResult {
  const MiniProgramShareResult({required this.chooserOpened});

  factory MiniProgramShareResult.fromJson(Map<String, dynamic> json) {
    final chooserOpened = json['chooserOpened'];
    if (chooserOpened is! bool || !chooserOpened) {
      throw const FormatException(
        'Mini-program share result must confirm that the chooser opened.',
      );
    }
    return const MiniProgramShareResult(chooserOpened: true);
  }

  final bool chooserOpened;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'chooserOpened': chooserOpened,
  };

  void validate() {
    if (!chooserOpened) {
      throw const FormatException(
        'Mini-program share result must confirm that the chooser opened.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MiniProgramShareResult && chooserOpened == other.chooserOpened;

  @override
  int get hashCode => chooserOpened.hashCode;
}
