import 'package:flutter/material.dart';

import 'mini_program_runtime.dart';

typedef MiniProgramRouteBuilder<T> =
    Route<T> Function(
      BuildContext context,
      MiniProgramLaunchRequest request,
      Widget page,
    );

@immutable
class MiniProgramLaunchOptions {
  const MiniProgramLaunchOptions({
    this.useRootNavigator = false,
    this.fullscreenDialog = false,
    this.showAppBar = true,
    this.backgroundColor,
    this.routeSettings,
    this.routeBuilder,
  });

  final bool useRootNavigator;
  final bool fullscreenDialog;
  final bool showAppBar;
  final Color? backgroundColor;
  final RouteSettings? routeSettings;
  final MiniProgramRouteBuilder<dynamic>? routeBuilder;
}

@immutable
class MiniProgramLaunchRequest {
  const MiniProgramLaunchRequest({
    required this.appId,
    required this.runtime,
    required this.page,
    required this.options,
    this.title,
    this.initialData,
    this.version,
    this.source,
  });

  final String appId;
  final String? title;
  final Map<String, dynamic>? initialData;
  final String? version;
  final Uri? source;
  final MiniProgramRuntime runtime;
  final Widget page;
  final MiniProgramLaunchOptions options;

  String get miniProgramId => appId;
}

typedef MiniProgramNavigationDelegate =
    Future<T?> Function<T>(
      BuildContext context,
      MiniProgramLaunchRequest request,
      Widget page,
    );
