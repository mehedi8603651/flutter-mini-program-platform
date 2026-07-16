part of '../../mp_screen_renderer.dart';

abstract final class _MpCompositionActionHandler {
  static Future<HostActionResult> _runSequence(
    BuildContext context,
    Map<String, dynamic> props,
    _MpRenderBindings bindings,
    _MpActionCallContext callContext,
  ) async {
    final steps = props['steps'];
    if (steps is! List || steps.any((step) => step is! _MpAction)) {
      return HostActionResult.failed(
        actionName: 'sequence',
        message: 'Mp sequence requires parsed action steps.',
        errorCode: MiniProgramErrorCodes.unknownAction,
      );
    }
    Object? lastResult;
    for (final step in steps) {
      lastResult = await _MpActionDispatcher.dispatch(
        context,
        step as _MpAction,
        bindings,
        callContext,
      );
      if (lastResult is HostActionResult && !lastResult.isSuccess) {
        return lastResult;
      }
    }
    return HostActionResult.success(
      actionName: 'sequence',
      data: <String, dynamic>{
        if (lastResult is HostActionResult) 'lastResult': lastResult.toJson(),
      },
    );
  }

  static Future<HostActionResult> _runIfElse(
    BuildContext context,
    Map<String, dynamic> props,
    _MpRenderBindings bindings,
    _MpActionCallContext callContext,
  ) async {
    const actionName = 'action.ifElse';
    final condition = props['condition'];
    if (condition is! bool) {
      return HostActionResult.failed(
        actionName: actionName,
        message: 'Mp action.ifElse condition must resolve to a boolean.',
        errorCode: MiniProgramErrorCodes.conditionInvalidValue,
        data: <String, dynamic>{'actualType': condition.runtimeType.toString()},
      );
    }
    final branch = condition ? 'then' : 'else';
    final selected = props[branch];
    if (selected is! _MpAction) {
      return HostActionResult.failed(
        actionName: actionName,
        message: 'Mp action.ifElse requires parsed then and else actions.',
        errorCode: MiniProgramErrorCodes.unknownAction,
      );
    }
    final result = await _MpActionDispatcher.dispatch(
      context,
      selected,
      bindings,
      callContext,
    );
    if (result is HostActionResult && !result.isSuccess) {
      return result;
    }
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{
        'branch': branch,
        if (result is HostActionResult) 'result': result.toJson(),
      },
    );
  }

  static Future<HostActionResult> _runNamedAction(
    BuildContext context,
    Map<String, dynamic> props,
    _MpRenderBindings bindings,
    _MpActionCallContext callContext,
  ) async {
    const actionName = 'action.call';
    final name = _stringProp(props, 'name');
    final definition = bindings.actionDefinitions[name];
    if (definition == null) {
      return HostActionResult.failed(
        actionName: actionName,
        message: 'Scoped Mp action "$name" was not found.',
        errorCode: MiniProgramErrorCodes.actionNotFound,
        data: <String, dynamic>{'name': name},
      );
    }
    if (callContext.stack.contains(name) ||
        callContext.stack.length >= _MpActionCallContext.maxDepth) {
      return HostActionResult.failed(
        actionName: actionName,
        message: 'Scoped Mp action call depth or recursion limit was exceeded.',
        errorCode: MiniProgramErrorCodes.actionCallLimitExceeded,
        data: <String, dynamic>{
          'name': name,
          'maxDepth': _MpActionCallContext.maxDepth,
          'callStack': <String>[...callContext.stack, name],
        },
      );
    }
    final result = await _MpActionDispatcher.dispatch(
      context,
      definition,
      bindings,
      callContext.push(name),
    );
    if (result is HostActionResult && !result.isSuccess) {
      return result;
    }
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{
        'name': name,
        if (result is HostActionResult) 'result': result.toJson(),
      },
    );
  }
}
