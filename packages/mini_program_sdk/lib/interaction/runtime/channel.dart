part of '../mini_program_interaction.dart';

/// Optional process-local Android task transport. Each engine binds its own
/// controller; the native relay forwards only to a focused foreground Activity.
/// Standard embedded hosts can call the controller directly.
class MiniProgramInteractionChannel {
  MiniProgramInteractionChannel({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('dev.miniprogram/foreground_interaction');

  final MethodChannel _channel;
  bool _bound = false;

  Future<void> bind(MiniProgramInteractionController controller) async {
    if (_bound) throw StateError('Interaction channel is already bound.');
    _bound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'dispatch' || call.arguments is! Map) {
        throw const FormatException('Invalid interaction relay request.');
      }
      return controller.handleRequest(
        Map<String, dynamic>.from(call.arguments as Map),
      );
    });
    try {
      await _channel.invokeMethod<void>('register');
    } on MissingPluginException {
      // The direct Dart controller remains usable in embedded/non-Android hosts.
    }
  }

  Future<Map<String, dynamic>> dispatch(Map<String, dynamic> request) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'dispatch',
      request,
    );
    return result ?? {'status': 'unavailable', 'code': 'foreground_required'};
  }

  Future<void> dispose() async {
    if (!_bound) return;
    _bound = false;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<void>('unregister');
    } on MissingPluginException {
      /* No native relay was installed. */
    }
  }
}
