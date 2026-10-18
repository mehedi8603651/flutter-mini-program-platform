import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';

typedef MpMapCoordinateSystem = MiniProgramMapCoordinateSystem;
typedef MpMapTravelMode = MiniProgramMapTravelMode;

/// Known destinations in a host-approved external map app, after a user tap.
final class MpMapsActions {
  const MpMapsActions();

  /// Displays the shop pin. Coordinates may be numbers or full bindings.
  MpAction openLocation({
    required Object latitude,
    required Object longitude,
    required String name,
    String address = '',
    MpMapCoordinateSystem coordinateSystem = MpMapCoordinateSystem.wgs84,
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _action(
    ActionNames.mapsOpenLocation,
    latitude,
    longitude,
    name,
    address,
    coordinateSystem,
    null,
    targetState,
    statusState,
    errorState,
    requestId,
  );

  /// Opens route planning to the shop. The map app owns origin selection,
  /// location consent and routing; the mini-program receives no device position.
  MpAction openDirections({
    required Object latitude,
    required Object longitude,
    required String name,
    String address = '',
    MpMapCoordinateSystem coordinateSystem = MpMapCoordinateSystem.wgs84,
    MpMapTravelMode mode = MpMapTravelMode.driving,
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _action(
    ActionNames.mapsOpenDirections,
    latitude,
    longitude,
    name,
    address,
    coordinateSystem,
    mode,
    targetState,
    statusState,
    errorState,
    requestId,
  );

  MpAction _action(
    String type,
    Object latitude,
    Object longitude,
    String name,
    String address,
    MpMapCoordinateSystem system,
    MpMapTravelMode? mode,
    String? target,
    String? status,
    String? error,
    String? request,
  ) {
    Object coordinate(Object value, bool latitude) {
      if (value is String && isFullBinding(value) && value.length <= 256) {
        return value;
      }
      return MiniProgramMapDestination.validateCoordinate(
        value,
        latitude: latitude,
      );
    }

    String text(String value, bool address) {
      if (isFullBinding(value) && value.length <= 256) return value;
      return MiniProgramMapDestination.validateText(value, address: address);
    }

    return MpAction(
      type,
      props: {
        'latitude': coordinate(latitude, true),
        'longitude': coordinate(longitude, false),
        'name': text(name, false),
        'address': text(address, true),
        'coordinateSystem': system.name,
        if (mode != null) 'mode': mode.name,
        if (target != null)
          'targetState': requiredStateKey(target, 'targetState'),
        if (status != null)
          'statusState': requiredStateKey(status, 'statusState'),
        if (error != null) 'errorState': requiredStateKey(error, 'errorState'),
        if (request != null)
          'requestId': stableAuthoringString(request, 'requestId'),
      },
    );
  }
}
