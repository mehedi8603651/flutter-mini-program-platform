part of '../../mp_screen_renderer.dart';

abstract final class _MpNavigationActionHandler {
  static Future<HostActionResult> _routerPush(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(_routerUnavailable('router.push'));
    }
    return router.push(
      _stringProp(props, 'screenId'),
      _mapProp(props, 'params'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerReplace(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(
        _routerUnavailable('router.replace'),
      );
    }
    return router.replace(
      _stringProp(props, 'screenId'),
      _mapProp(props, 'params'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerReset(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(_routerUnavailable('router.reset'));
    }
    return router.reset(
      _stringProp(props, 'screenId'),
      _mapProp(props, 'params'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerPop(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(_routerUnavailable('router.pop'));
    }
    return router.pop(
      _mapProp(props, 'result'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerPopToRoot(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(
        _routerUnavailable('router.popToRoot'),
      );
    }
    return router.popToRoot(
      _mapProp(props, 'result'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerPopToScreen(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(
        _routerUnavailable('router.popToScreen'),
      );
    }
    return router.popToScreen(
      _stringProp(props, 'screenId'),
      _mapProp(props, 'result'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static HostActionResult _routerUnavailable(String actionName) {
    return HostActionResult.failed(
      actionName: actionName,
      message: 'Mp router is unavailable.',
      errorCode: 'router_unavailable',
    );
  }
}
