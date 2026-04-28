import 'package:flutter/material.dart';

import 'mini_program_config.dart';
import 'mini_program_launch_options.dart';
import 'mini_program_page.dart';
import 'mini_program_runtime.dart';

class MiniProgramController {
  MiniProgramController({
    required MiniProgramConfig config,
    this.navigationDelegate,
  }) : _config = config,
       _runtime = null,
       _disposeInjectedRuntime = false;

  MiniProgramController.runtime(
    MiniProgramRuntime runtime, {
    this.navigationDelegate,
    bool disposeRuntime = false,
  }) : _config = null,
       _runtime = runtime,
       _disposeInjectedRuntime = disposeRuntime;

  final MiniProgramConfig? _config;
  MiniProgramRuntime? _runtime;
  final bool _disposeInjectedRuntime;
  final MiniProgramNavigationDelegate? navigationDelegate;

  bool _createdRuntimeFromConfig = false;
  bool _disposed = false;

  MiniProgramRuntime get runtime {
    _throwIfDisposed();

    final existingRuntime = _runtime;
    if (existingRuntime != null) {
      return existingRuntime;
    }

    final config = _config;
    if (config == null) {
      throw StateError('MiniProgramController has no runtime or config.');
    }

    final runtime = config.createRuntime();
    _runtime = runtime;
    _createdRuntimeFromConfig = true;
    return runtime;
  }

  Future<T?> openMiniProgram<T>(
    BuildContext context, {
    required String appId,
    String? title,
    Map<String, dynamic>? initialData,
    String? version,
    Uri? source,
    MiniProgramLaunchOptions options = const MiniProgramLaunchOptions(),
  }) {
    _throwIfDisposed();

    final normalizedAppId = appId.trim();
    if (normalizedAppId.isEmpty) {
      throw ArgumentError.value(appId, 'appId', 'appId must not be blank.');
    }

    final resolvedRuntime = runtime;
    final page = MiniProgramPage(
      miniProgramId: normalizedAppId,
      title: title,
      runtime: resolvedRuntime,
    );
    final request = MiniProgramLaunchRequest(
      appId: normalizedAppId,
      title: title,
      initialData: initialData,
      version: version,
      source: source,
      runtime: resolvedRuntime,
      page: page,
      options: options,
    );

    final delegate = navigationDelegate;
    if (delegate != null) {
      return delegate<T>(context, request, page);
    }

    return _pushMiniProgramPage<T>(context, request);
  }

  Future<T?> _pushMiniProgramPage<T>(
    BuildContext context,
    MiniProgramLaunchRequest request,
  ) {
    final options = request.options;
    final navigator = Navigator.of(
      context,
      rootNavigator: options.useRootNavigator,
    );
    final route =
        options.routeBuilder?.call(context, request, request.page)
            as Route<T>? ??
        MaterialPageRoute<T>(
          builder: (_) => request.page,
          settings: options.routeSettings,
          fullscreenDialog: options.fullscreenDialog,
        );
    return navigator.push<T>(route);
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    final runtime = _runtime;
    if (runtime != null &&
        (_createdRuntimeFromConfig || _disposeInjectedRuntime)) {
      runtime.dispose();
    } else if (runtime == null) {
      _config?.disposeOwnedResources();
    }

    _disposed = true;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('MiniProgramController has been disposed.');
    }
  }
}
