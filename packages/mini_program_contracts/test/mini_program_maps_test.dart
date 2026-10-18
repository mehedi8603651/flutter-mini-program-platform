import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test(
    'map destinations round-trip explicit coordinates and bounded metadata',
    () {
      for (final system in MiniProgramMapCoordinateSystem.values) {
        final destination = MiniProgramMapDestination(
          latitude: 23.8103,
          longitude: 90.4125,
          name: '  Food & tea 店  ',
          address: 'Dhaka',
          coordinateSystem: system,
        );
        expect(
          MiniProgramMapDestination.fromJson(destination.toJson()).toJson(),
          destination.toJson(),
        );
        expect(destination.name, 'Food & tea 店');
        expect(destination.coordinateSystem, system);
      }
      expect(
        CapabilityIds.standardValues,
        containsAll([
          CapabilityIds.mapsOpenLocation,
          CapabilityIds.mapsOpenDirections,
        ]),
      );
    },
  );

  test(
    'map contracts reject invalid coordinates and executable destination fields',
    () {
      final valid = MiniProgramMapDestination(
        latitude: 0,
        longitude: 0,
        name: 'Shop',
      ).toJson();
      for (final patch in <Map<String, dynamic>>[
        {'latitude': 91},
        {'latitude': double.nan},
        {'latitude': '23.8'},
        {'longitude': -181},
        {'longitude': double.infinity},
        {'name': ''},
        {'name': 'x' * 121},
        {'name': 'shop\n'},
        {'address': 'x' * 513},
        {'address': '\u0000'},
        {'coordinateSystem': 'auto'},
        {'url': 'intent://evil'},
        {'package': 'malicious.app'},
      ]) {
        expect(
          () => MiniProgramMapDestination.fromJson({...valid, ...patch}),
          throwsFormatException,
        );
      }
      for (final lat in [-90, 90]) {
        for (final lon in [-180, 180]) {
          expect(
            MiniProgramMapDestination(
              latitude: lat,
              longitude: lon,
              name: 'Edge',
            ).latitude,
            lat,
          );
        }
      }
    },
  );
}
