/// Supported current-location accuracy levels.
enum MiniProgramLocationAccuracy { approximate }

/// Supported location access modes.
enum MiniProgramLocationMode { whenInUse }

extension MiniProgramLocationAccuracyX on MiniProgramLocationAccuracy {
  String get wireValue => switch (this) {
    MiniProgramLocationAccuracy.approximate => 'approximate',
  };
}

extension MiniProgramLocationModeX on MiniProgramLocationMode {
  String get wireValue => switch (this) {
    MiniProgramLocationMode.whenInUse => 'whenInUse',
  };
}

MiniProgramLocationAccuracy miniProgramLocationAccuracyFromWire(String value) {
  return switch (value) {
    'approximate' => MiniProgramLocationAccuracy.approximate,
    _ => throw FormatException('Unsupported location accuracy "$value".'),
  };
}

MiniProgramLocationMode miniProgramLocationModeFromWire(String value) {
  return switch (value) {
    'whenInUse' => MiniProgramLocationMode.whenInUse,
    _ => throw FormatException('Unsupported location mode "$value".'),
  };
}

/// JSON-safe result returned by a host current-location provider.
class MiniProgramLocationResult {
  const MiniProgramLocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAtUtc,
    this.source = deviceSource,
  });

  factory MiniProgramLocationResult.fromJson(Map<String, dynamic> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final accuracyMeters = json['accuracyMeters'];
    final capturedAtUtc = json['capturedAtUtc'];
    final source = json['source'];
    if (latitude is! num ||
        longitude is! num ||
        accuracyMeters is! num ||
        capturedAtUtc is! String ||
        source is! String) {
      throw const FormatException('Invalid mini-program location result.');
    }
    final capturedAt = DateTime.tryParse(capturedAtUtc);
    if (capturedAt == null) {
      throw const FormatException(
        'Location capturedAtUtc must be an ISO-8601 timestamp.',
      );
    }
    final result = MiniProgramLocationResult(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracyMeters: accuracyMeters.toDouble(),
      capturedAtUtc: capturedAt,
      source: source,
    );
    result.validate();
    return result;
  }

  static const String deviceSource = 'device';

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAtUtc;
  final String source;

  void validate() {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw const FormatException(
        'Location latitude must be finite and between -90 and 90.',
      );
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw const FormatException(
        'Location longitude must be finite and between -180 and 180.',
      );
    }
    if (!accuracyMeters.isFinite || accuracyMeters < 0) {
      throw const FormatException(
        'Location accuracyMeters must be finite and non-negative.',
      );
    }
    if (!capturedAtUtc.isUtc) {
      throw const FormatException('Location capturedAtUtc must be UTC.');
    }
    if (source != deviceSource) {
      throw const FormatException('Location source must be "device".');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'capturedAtUtc': capturedAtUtc.toIso8601String(),
      'source': source,
    };
  }
}
