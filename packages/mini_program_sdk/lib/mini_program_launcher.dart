import 'package:flutter/material.dart';

import 'mini_program_page.dart';
import 'mini_program_runtime.dart';

typedef MiniProgramRouteBuilder<T> =
    Route<T> Function(BuildContext context, Widget page);

Future<T?> openMiniProgram<T>(
  BuildContext context, {
  required String miniProgramId,
  String? title,
  MiniProgramRuntime? runtime,
  bool useRootNavigator = false,
  MiniProgramRouteBuilder<T>? routeBuilder,
}) {
  final page = MiniProgramPage(
    miniProgramId: miniProgramId,
    title: title,
    runtime: runtime,
  );
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final route =
      routeBuilder?.call(context, page) ??
      MaterialPageRoute<T>(builder: (_) => page);
  return navigator.push<T>(route);
}

class MiniProgramLauncherButton extends StatelessWidget {
  const MiniProgramLauncherButton({
    super.key,
    required this.miniProgramId,
    required this.child,
    this.title,
    this.runtime,
    this.icon,
    this.style,
    this.useRootNavigator = false,
    this.routeBuilder,
  });

  final String miniProgramId;
  final Widget child;
  final String? title;
  final MiniProgramRuntime? runtime;
  final Widget? icon;
  final ButtonStyle? style;
  final bool useRootNavigator;
  final MiniProgramRouteBuilder<void>? routeBuilder;

  @override
  Widget build(BuildContext context) {
    void handlePressed() {
      openMiniProgram<void>(
        context,
        miniProgramId: miniProgramId,
        title: title,
        runtime: runtime,
        useRootNavigator: useRootNavigator,
        routeBuilder: routeBuilder,
      );
    }

    if (icon != null) {
      return FilledButton.icon(
        onPressed: handlePressed,
        style: style,
        icon: icon!,
        label: child,
      );
    }

    return FilledButton(
      onPressed: handlePressed,
      style: style,
      child: child,
    );
  }
}
