import 'package:flutter/material.dart';

import 'mini_program_launch_options.dart';
import 'mini_program_page.dart';
import 'mini_program_runtime.dart';
import 'mini_program_scope.dart';

typedef LegacyMiniProgramRouteBuilder<T> =
    Route<T> Function(BuildContext context, Widget page);

@Deprecated(
  'Use MiniProgramScope.of(context).openMiniProgram(appId: ...) instead. '
  'The free launcher helper will be removed in the next major version.',
)
Future<T?> openMiniProgram<T>(
  BuildContext context, {
  required String miniProgramId,
  String? title,
  MiniProgramRuntime? runtime,
  bool useRootNavigator = false,
  LegacyMiniProgramRouteBuilder<T>? routeBuilder,
}) {
  return _pushMiniProgramPage<T>(
    context,
    page: MiniProgramPage(
      miniProgramId: miniProgramId,
      title: title,
      runtime: runtime,
    ),
    useRootNavigator: useRootNavigator,
    routeBuilder: routeBuilder,
  );
}

class MiniProgramLauncher extends StatelessWidget {
  const MiniProgramLauncher({
    super.key,
    required this.appId,
    required this.child,
    this.title,
    this.initialData,
    this.version,
    this.source,
    this.options = const MiniProgramLaunchOptions(),
    this.enabled = true,
  });

  final String appId;
  final Widget child;
  final String? title;
  final Map<String, dynamic>? initialData;
  final String? version;
  final Uri? source;
  final MiniProgramLaunchOptions options;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                MiniProgramScope.of(context).openMiniProgram<void>(
                  appId: appId,
                  title: title,
                  initialData: initialData,
                  version: version,
                  source: source,
                  options: options,
                );
              }
            : null,
        child: child,
      ),
    );
  }
}

@Deprecated(
  'Use MiniProgramLauncher or MiniProgramScope.of(context).openMiniProgram(appId: ...) '
  'instead. MiniProgramLauncherButton will be removed in the next major version.',
)
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
  final LegacyMiniProgramRouteBuilder<void>? routeBuilder;

  @override
  Widget build(BuildContext context) {
    void handlePressed() {
      _pushMiniProgramPage<void>(
        context,
        page: MiniProgramPage(
          miniProgramId: miniProgramId,
          title: title,
          runtime: runtime,
        ),
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

    return FilledButton(onPressed: handlePressed, style: style, child: child);
  }
}

Future<T?> _pushMiniProgramPage<T>(
  BuildContext context, {
  required Widget page,
  required bool useRootNavigator,
  LegacyMiniProgramRouteBuilder<T>? routeBuilder,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final route =
      routeBuilder?.call(context, page) ??
      MaterialPageRoute<T>(builder: (_) => page);
  return navigator.push<T>(route);
}
