import 'package:flutter/widgets.dart';

import 'mini_program_config.dart';
import 'mini_program_controller.dart';
import 'mini_program_launch_options.dart';

class MiniProgramScope extends StatefulWidget {
  const MiniProgramScope({
    super.key,
    required this.child,
    this.config,
    this.controller,
    this.disposeController = false,
    this.navigationDelegate,
  }) : assert(
         config != null || controller != null,
         'MiniProgramScope requires either config or controller.',
       ),
       assert(
         config == null || controller == null,
         'MiniProgramScope accepts either config or controller, not both.',
       ),
       assert(
         controller == null || navigationDelegate == null,
         'Pass navigationDelegate to MiniProgramController when injecting a controller.',
       ),
       assert(
         controller != null || !disposeController,
         'disposeController only applies when controller is injected.',
       );

  final Widget child;
  final MiniProgramConfig? config;
  final MiniProgramController? controller;
  final bool disposeController;
  final MiniProgramNavigationDelegate? navigationDelegate;

  static MiniProgramScopeHandle of(BuildContext context) {
    final handle = maybeOf(context);
    if (handle == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          'MiniProgramScope not found. Wrap your app with MiniProgramScope(config: buildMiniProgramConfig(), child: MyApp()).',
        ),
        ErrorDescription(
          'Mini-program APIs need a MiniProgramScope ancestor so the SDK can '
          'find the host runtime configuration.',
        ),
      ]);
    }

    return handle;
  }

  static MiniProgramScopeHandle? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedMiniProgramScope>();
    if (scope == null) {
      return null;
    }

    return MiniProgramScopeHandle._(context, scope.controller);
  }

  @override
  State<MiniProgramScope> createState() => _MiniProgramScopeState();
}

class _MiniProgramScopeState extends State<MiniProgramScope> {
  late final MiniProgramController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.config == null && widget.controller == null) {
      throw FlutterError(
        'MiniProgramScope requires either config or controller.',
      );
    }
    if (widget.config != null && widget.controller != null) {
      throw FlutterError(
        'MiniProgramScope accepts either config or controller, not both.',
      );
    }
    if (widget.controller != null && widget.navigationDelegate != null) {
      throw FlutterError(
        'Pass navigationDelegate to MiniProgramController when injecting a controller.',
      );
    }
    if (widget.controller == null && widget.disposeController) {
      throw FlutterError(
        'disposeController only applies when controller is injected.',
      );
    }

    final injectedController = widget.controller;
    if (injectedController != null) {
      _controller = injectedController;
      _ownsController = widget.disposeController;
      return;
    }

    _controller = MiniProgramController(
      config: widget.config!,
      navigationDelegate: widget.navigationDelegate,
    );
    _ownsController = true;
  }

  @override
  void didUpdateWidget(covariant MiniProgramScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.config, oldWidget.config) ||
        !identical(widget.controller, oldWidget.controller) ||
        widget.disposeController != oldWidget.disposeController ||
        !identical(widget.navigationDelegate, oldWidget.navigationDelegate)) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          'MiniProgramScope configuration cannot change after creation.',
        ),
        ErrorDescription(
          'MiniProgramScope treats config, controller, disposeController, and '
          'navigationDelegate as immutable for the lifetime of the widget state.',
        ),
        ErrorHint(
          'To switch mini-program environments or runtime ownership, recreate '
          'the scope with a new key, for example '
          'MiniProgramScope(key: ValueKey(environment), config: config, child: MyApp()).',
        ),
      ]);
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedMiniProgramScope(
      controller: _controller,
      child: widget.child,
    );
  }
}

class MiniProgramScopeHandle {
  const MiniProgramScopeHandle._(this._context, this.controller);

  final BuildContext _context;
  final MiniProgramController controller;

  Future<T?> openMiniProgram<T>({
    required String appId,
    String? title,
    Map<String, dynamic>? initialData,
    String? version,
    Uri? source,
    MiniProgramLaunchOptions options = const MiniProgramLaunchOptions(),
  }) {
    return controller.openMiniProgram<T>(
      _context,
      appId: appId,
      title: title,
      initialData: initialData,
      version: version,
      source: source,
      options: options,
    );
  }
}

class _InheritedMiniProgramScope extends InheritedWidget {
  const _InheritedMiniProgramScope({
    required this.controller,
    required super.child,
  });

  final MiniProgramController controller;

  @override
  bool updateShouldNotify(_InheritedMiniProgramScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
