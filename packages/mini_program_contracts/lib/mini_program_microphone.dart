/// Bounded metadata for an app-owned AAC voice recording. Native locations and
/// audio bytes are deliberately excluded from this contract.
class MiniProgramMicrophoneResult {
  MiniProgramMicrophoneResult({
    required this.recordingId,
    required this.mediaRef,
    required this.fileName,
    required this.bytes,
    required this.durationMs,
    required this.stopReason,
    required this.recordedAtUtc,
  }) {
    validate();
  }

  factory MiniProgramMicrophoneResult.fromJson(Map<String, dynamic> json) {
    if (json['recordingId'] is! String ||
        json['mediaRef'] is! String ||
        json['fileName'] is! String ||
        json['bytes'] is! int ||
        json['durationMs'] is! int ||
        json['stopReason'] is! String ||
        json['recordedAtUtc'] is! String ||
        json['mimeType'] != 'audio/mp4' ||
        json['codec'] != 'aac' ||
        json['sampleRate'] != 16000 ||
        json['channels'] != 1) {
      throw const FormatException('Invalid microphone recording metadata.');
    }
    final timestamp = DateTime.tryParse(json['recordedAtUtc'] as String);
    if (timestamp == null) {
      throw const FormatException('Invalid microphone recording timestamp.');
    }
    return MiniProgramMicrophoneResult(
      recordingId: json['recordingId'] as String,
      mediaRef: json['mediaRef'] as String,
      fileName: json['fileName'] as String,
      bytes: json['bytes'] as int,
      durationMs: json['durationMs'] as int,
      stopReason: json['stopReason'] as String,
      recordedAtUtc: timestamp,
    );
  }

  final String recordingId;
  final String mediaRef;
  final String fileName;
  final int bytes;
  final int durationMs;
  final String stopReason;
  final DateTime recordedAtUtc;

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(recordingId) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(mediaRef) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,150}\.m4a$').hasMatch(fileName) ||
        bytes < 1 ||
        bytes > 100 * 1024 * 1024 ||
        durationMs < 1 ||
        durationMs > 601000 ||
        !const {
          'user',
          'durationLimit',
          'sizeLimit',
          'background',
        }.contains(stopReason) ||
        !recordedAtUtc.isUtc) {
      throw const FormatException('Invalid microphone recording metadata.');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'recordingId': recordingId,
      'mediaRef': mediaRef,
      'fileName': fileName,
      'mimeType': 'audio/mp4',
      'bytes': bytes,
      'durationMs': durationMs,
      'codec': 'aac',
      'sampleRate': 16000,
      'channels': 1,
      'stopReason': stopReason,
      'recordedAtUtc': recordedAtUtc.toIso8601String(),
    };
  }
}
