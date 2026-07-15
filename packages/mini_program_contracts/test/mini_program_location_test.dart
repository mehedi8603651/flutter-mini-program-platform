import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('serializes and parses a validated device location result', () {
    final capturedAt = DateTime.utc(2026, 7, 15, 10, 30);
    final result = MiniProgramLocationResult(
      latitude: 23.8103,
      longitude: 90.4125,
      accuracyMeters: 850,
      capturedAtUtc: capturedAt,
    );

    final json = result.toJson();
    expect(json, <String, dynamic>{
      'latitude': 23.8103,
      'longitude': 90.4125,
      'accuracyMeters': 850.0,
      'capturedAtUtc': '2026-07-15T10:30:00.000Z',
      'source': 'device',
    });
    expect(MiniProgramLocationResult.fromJson(json).toJson(), json);
  });

  test('rejects invalid location values', () {
    expect(
      () => MiniProgramLocationResult(
        latitude: 91,
        longitude: 90,
        accuracyMeters: 10,
        capturedAtUtc: DateTime.utc(2026),
      ).toJson(),
      throwsFormatException,
    );
    expect(
      () => MiniProgramLocationResult(
        latitude: 23,
        longitude: 90,
        accuracyMeters: -1,
        capturedAtUtc: DateTime.utc(2026),
      ).toJson(),
      throwsFormatException,
    );
    expect(
      () => MiniProgramLocationResult(
        latitude: 23,
        longitude: 90,
        accuracyMeters: 10,
        capturedAtUtc: DateTime(2026),
      ).toJson(),
      throwsFormatException,
    );
  });

  test('exports stable location action capability and errors', () {
    expect(ActionNames.locationGetCurrent, 'location.getCurrent');
    expect(CapabilityIds.locationCurrent, 'location.current');
    expect(
      MiniProgramErrorCodes.locationPermissionDeniedPermanently,
      'location_permission_denied_permanently',
    );
    expect(
      miniProgramLocationAccuracyFromWire('approximate'),
      MiniProgramLocationAccuracy.approximate,
    );
    expect(
      miniProgramLocationModeFromWire('whenInUse'),
      MiniProgramLocationMode.whenInUse,
    );
  });
}
