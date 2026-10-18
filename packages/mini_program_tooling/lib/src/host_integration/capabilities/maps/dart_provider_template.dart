String buildAndroidMapsProvider() => r'''
import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host preference only; mini-program JSON cannot choose apps or supply URLs.
enum AppAndroidMapApp { googleMaps, amap, baiduMaps }

/// Host-owned adapter, preserved on regeneration. The first compatible
/// installed app in this list is used. No browser fallback or location access.
class AppAndroidMapsProvider implements MiniProgramMapsProvider {
  const AppAndroidMapsProvider({
    this.preferredApps = const [AppAndroidMapApp.googleMaps,
      AppAndroidMapApp.amap, AppAndroidMapApp.baiduMaps],
    MethodChannel channel = const MethodChannel('mini_program/maps'),
  }) : _channel = channel;
  final List<AppAndroidMapApp> preferredApps;
  final MethodChannel _channel;

  @override
  Future<void> openLocation({required String miniProgramId,
      required MiniProgramMapDestination destination}) =>
      _open('openLocation', miniProgramId, destination);

  @override
  Future<void> openDirections({required String miniProgramId,
      required MiniProgramMapDestination destination,
      required MiniProgramMapTravelMode mode}) =>
      _open('openDirections', miniProgramId, destination, mode: mode);

  Future<void> _open(String method, String appId,
      MiniProgramMapDestination destination, {MiniProgramMapTravelMode? mode}) async {
    // Revalidate even for host-created objects and keep native arguments bounded.
    final checked = MiniProgramMapDestination.fromJson(destination.toJson());
    if (preferredApps.isEmpty || preferredApps.length > 3 ||
        preferredApps.toSet().length != preferredApps.length) {
      throw const MiniProgramMapsException(errorCode: 'maps_invalid_request',
        message: 'Configure one to three distinct map apps.');
    }
    try {
      await _channel.invokeMethod<void>(method, {
        'miniProgramId': appId, ...checked.toJson(),
        'preferredApps': preferredApps.map((app) => app.name).toList(),
        if (mode != null) 'mode': mode.name,
      });
    } on MissingPluginException {
      throw const MiniProgramMapsException(errorCode: 'maps_unavailable',
        message: 'The Android maps adapter is unavailable.');
    } on PlatformException catch (error) {
      const codes = {'maps_unavailable', 'maps_foreground_required',
        'maps_invalid_request', 'maps_coordinate_system_unsupported', 'maps_operation_failed'};
      throw MiniProgramMapsException(
        errorCode: codes.contains(error.code) ? error.code : 'maps_operation_failed',
        message: 'The map application could not be opened.');
    }
  }
}
''';
