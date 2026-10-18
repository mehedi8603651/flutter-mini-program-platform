import 'dart:convert';
import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test(
    'shop pin and directions authoring emits deterministic explicit JSON',
    () {
      final location = Mp.maps.openLocation(
        latitude: 23.8103,
        longitude: 90.4125,
        name: 'Food shop',
        address: 'Dhaka',
        targetState: 'map.result',
      );
      expect(location.toJson(), {
        'type': 'maps.openLocation',
        'props': {
          'latitude': 23.8103,
          'longitude': 90.4125,
          'name': 'Food shop',
          'address': 'Dhaka',
          'coordinateSystem': 'wgs84',
          'targetState': 'map.result',
        },
      });
      final directions = Mp.maps.openDirections(
        latitude: '{{state.shop.lat}}',
        longitude: '{{state.shop.lon}}',
        name: '{{state.shop.name}}',
        coordinateSystem: MpMapCoordinateSystem.gcj02,
        mode: MpMapTravelMode.walking,
        statusState: 'map.status',
        errorState: 'map.error',
        requestId: 'shop_route',
      );
      final props = directions.toJson()['props'] as Map;
      expect(props['latitude'], '{{state.shop.lat}}');
      expect(props['coordinateSystem'], 'gcj02');
      expect(props['mode'], 'walking');
      expect(jsonEncode(directions.toJson()), jsonEncode(directions.toJson()));
      expect(
        jsonEncode(location.toJson()),
        isNot(contains('location.getCurrent')),
      );
    },
  );

  test(
    'map authoring rejects invalid literals and unsafe state destinations',
    () {
      for (final value in <Object>[
        91,
        double.nan,
        '23.8',
        'prefix {{state.lat}}',
        true,
      ]) {
        expect(
          () => Mp.maps.openLocation(
            latitude: value,
            longitude: 90,
            name: 'Shop',
          ),
          throwsA(anything),
        );
      }
      expect(
        () => Mp.maps.openDirections(latitude: 0, longitude: 181, name: 'Shop'),
        throwsA(anything),
      );
      expect(
        () => Mp.maps.openLocation(latitude: 0, longitude: 0, name: 'Shop\n'),
        throwsA(anything),
      );
      expect(
        () => Mp.maps.openLocation(
          latitude: 0,
          longitude: 0,
          name: 'Shop',
          targetState: '{{state.key}}',
        ),
        throwsA(anything),
      );
    },
  );
}
