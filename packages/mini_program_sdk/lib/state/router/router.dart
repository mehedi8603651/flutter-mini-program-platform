part of '../mp_state.dart';

typedef MpRouterScreenHandler =
    Future<HostActionResult> Function(
      String screenId,
      Map<String, dynamic> params,
      String? requestId,
    );

typedef MpRouterResultHandler =
    Future<HostActionResult> Function(
      Map<String, dynamic> result,
      String? requestId,
    );

typedef MpRouterPopToScreenHandler =
    Future<HostActionResult> Function(
      String screenId,
      Map<String, dynamic> result,
      String? requestId,
    );

/// Lightweight router facade used by Mp JSON actions.
class MpRouter {
  /// Creates a router facade over the active mini-program stack.
  const MpRouter({
    required this.push,
    required this.replace,
    required this.reset,
    required this.pop,
    required this.popToRoot,
    required this.popToScreen,
  });

  /// Pushes [screenId] and exposes [params] under `{{route.*}}`.
  final MpRouterScreenHandler push;

  /// Replaces the current screen with [screenId].
  final MpRouterScreenHandler replace;

  /// Resets the stack to [screenId].
  final MpRouterScreenHandler reset;

  /// Pops the current screen and returns [result] to the revealed screen.
  final MpRouterResultHandler pop;

  /// Pops to the root screen and returns [result].
  final MpRouterResultHandler popToRoot;

  /// Pops to [screenId] and returns [result].
  final MpRouterPopToScreenHandler popToScreen;
}
