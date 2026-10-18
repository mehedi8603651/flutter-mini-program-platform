/// Coordinate reference supplied by the shop/publisher. Providers must honor
/// this value or reject the request; these coordinate systems are not equal.
enum MiniProgramMapCoordinateSystem { wgs84, gcj02, bd09 }

/// Route planning modes shared by the supported Android adapters.
enum MiniProgramMapTravelMode { driving, walking }

/// A known shop/destination, never an arbitrary URL, package, or Intent.
class MiniProgramMapDestination {
  MiniProgramMapDestination({
    required num latitude,
    required num longitude,
    required String name,
    String address = '',
    this.coordinateSystem = MiniProgramMapCoordinateSystem.wgs84,
  }) : latitude = validateCoordinate(latitude, latitude: true),
       longitude = validateCoordinate(longitude, latitude: false),
       name = validateText(name),
       address = validateText(address, address: true);

  factory MiniProgramMapDestination.fromJson(Map<String, dynamic> json) {
    const keys = {
      'latitude',
      'longitude',
      'name',
      'address',
      'coordinateSystem',
    };
    if (json.keys.any((key) => !keys.contains(key))) {
      throw const FormatException('Unknown map destination property.');
    }
    final system = json['coordinateSystem'] ?? 'wgs84';
    if (!MiniProgramMapCoordinateSystem.values.any((v) => v.name == system)) {
      throw const FormatException('Unknown map coordinate system.');
    }
    return MiniProgramMapDestination(
      latitude: validateCoordinate(json['latitude'], latitude: true),
      longitude: validateCoordinate(json['longitude'], latitude: false),
      name: validateText(json['name']),
      address: validateText(json['address'] ?? '', address: true),
      coordinateSystem: MiniProgramMapCoordinateSystem.values.byName(
        system as String,
      ),
    );
  }

  final double latitude;
  final double longitude;
  final String name;
  final String address;
  final MiniProgramMapCoordinateSystem coordinateSystem;

  static double validateCoordinate(Object? value, {required bool latitude}) {
    final limit = latitude ? 90 : 180;
    if (value is! num || !value.isFinite || value < -limit || value > limit) {
      throw const FormatException(
        'Map coordinates must be finite and in range.',
      );
    }
    return value.toDouble();
  }

  static String validateText(Object? value, {bool address = false}) {
    if (value is! String ||
        value.length > (address ? 512 : 120) ||
        (!address && value.trim().isEmpty) ||
        RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(value)) {
      throw const FormatException('Invalid or oversized map destination text.');
    }
    return value.trim();
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'name': name,
    'address': address,
    'coordinateSystem': coordinateSystem.name,
  };
}
