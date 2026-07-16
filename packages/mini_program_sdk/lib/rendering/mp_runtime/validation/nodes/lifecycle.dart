part of '../../../mp_screen_renderer.dart';

extension _MpLifecycleNodeValidation on MpScreenValidator {
  _MpNode _parseRefreshIndicatorNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    if (path != r'$.root') {
      _fail(
        'Mp refreshIndicator is supported only as the screen root.',
        path: path,
      );
    }
    _validateObjectKeys(props, const <String>{
      'action',
      'semanticsLabel',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'refreshIndicator', path: path);
    return _MpNode(
      type: 'refreshIndicator',
      props: <String, dynamic>{
        'action': _parseAction(props['action'], path: '$path.props.action'),
        if (props.containsKey('semanticsLabel'))
          'semanticsLabel': _requiredString(
            props,
            'semanticsLabel',
            path: '$path.props',
          ),
      },
      children: children,
    );
  }

  _MpNode _parseInitializeNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'actions',
      'loading',
      'error',
      'statusState',
      'errorState',
      'retry',
      'retryDelayMs',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'initialize', path: path);
    final actions = _parseLazyActions(
      props['actions'],
      path: '$path.props.actions',
    );
    if (actions.isEmpty) {
      _fail(
        'Mp initialize requires at least one action.',
        path: '$path.props.actions',
      );
    }
    final retry =
        _optionalNonNegativeInt(props['retry'], path: '$path.props.retry') ?? 0;
    final retryDelayMs =
        _optionalNonNegativeInt(
          props['retryDelayMs'],
          path: '$path.props.retryDelayMs',
        ) ??
        300;
    if (retry > 10) {
      _fail('Mp initialize retry cannot exceed 10.', path: '$path.props.retry');
    }
    if (retryDelayMs > 60000) {
      _fail(
        'Mp initialize retryDelayMs cannot exceed 60000.',
        path: '$path.props.retryDelayMs',
      );
    }
    return _MpNode(
      type: 'initialize',
      props: <String, dynamic>{
        'actions': actions,
        'retry': retry,
        'retryDelayMs': retryDelayMs,
        if (props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
          ),
        if (props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        ..._parseTemplateProps(
          props,
          const <String>{'loading', 'error'},
          path: '$path.props',
          depth: depth,
          state: state,
        ),
      },
      children: children,
    );
  }

  _MpNode _parseStateScopeNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'prefix',
      'clearOnDispose',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'stateScope', path: path);
    return _MpNode(
      type: 'stateScope',
      props: <String, dynamic>{
        'prefix': _requiredStateKey(props, 'prefix', path: '$path.props'),
        'clearOnDispose': props.containsKey('clearOnDispose')
            ? _requiredBoolValue(
                props['clearOnDispose'],
                path: '$path.props.clearOnDispose',
              )
            : true,
      },
      children: children,
    );
  }

  _MpNode _parseActionScopeNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{'actions'}, path: '$path.props');
    _validateSingleChild(children, nodeType: 'actionScope', path: path);
    final rawActions = props['actions'];
    if (rawActions is! Map || rawActions.isEmpty) {
      _fail(
        'Mp actionScope requires a non-empty actions object.',
        path: '$path.props.actions',
      );
    }
    if (rawActions.length > MpScreenValidator.maxActionDefinitions) {
      _fail(
        'Mp actionScope cannot define more than ${MpScreenValidator.maxActionDefinitions} actions.',
        path: '$path.props.actions',
        details: <String, dynamic>{
          'actual': rawActions.length,
          'maximum': MpScreenValidator.maxActionDefinitions,
        },
      );
    }
    final actions = <String, _MpAction>{};
    for (final entry in rawActions.entries) {
      final rawName = entry.key;
      if (rawName is! String) {
        _fail(
          'Mp actionScope action names must be strings.',
          path: '$path.props.actions',
        );
      }
      final name = _validateActionName(
        rawName,
        path: '$path.props.actions.$rawName',
      );
      if (actions.containsKey(name)) {
        _fail(
          'Mp actionScope action names must be unique.',
          path: '$path.props.actions.$rawName',
        );
      }
      actions[name] = _parseAction(
        entry.value,
        path: '$path.props.actions.$rawName',
      );
    }
    return _MpNode(
      type: 'actionScope',
      props: <String, dynamic>{'actions': actions},
      children: children,
    );
  }

  _MpNode _parseConditionNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'condition',
      'whenTrue',
      'whenFalse',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final parsedProps = <String, dynamic>{
      'condition': _requiredBooleanOrBindingValue(
        props['condition'],
        path: '$path.props.condition',
      ),
      ..._parseTemplateProps(
        props,
        const <String>{'whenTrue', 'whenFalse'},
        path: '$path.props',
        depth: depth,
        state: state,
      ),
    };
    if (!parsedProps.containsKey('whenTrue')) {
      _fail(
        'Mp condition requires a whenTrue template.',
        path: '$path.props.whenTrue',
      );
    }
    return _MpNode(
      type: 'condition',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseCountdownNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'durationMs',
      'running',
      'restartToken',
      'remainingState',
      'onComplete',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'countdown', path: path);
    final durationMs = _requiredPositiveIntValue(
      props['durationMs'],
      path: '$path.props.durationMs',
    );
    if (durationMs > MpScreenValidator.maxCountdownDurationMs) {
      _fail(
        'Mp countdown durationMs cannot exceed ${MpScreenValidator.maxCountdownDurationMs}.',
        path: '$path.props.durationMs',
      );
    }
    final remainingState = props.containsKey('remainingState')
        ? _requiredStateKey(props, 'remainingState', path: '$path.props')
        : null;
    final onComplete = props.containsKey('onComplete')
        ? _parseAction(props['onComplete'], path: '$path.props.onComplete')
        : null;
    if (remainingState == null && onComplete == null) {
      _fail(
        'Mp countdown requires remainingState or onComplete.',
        path: '$path.props',
      );
    }
    return _MpNode(
      type: 'countdown',
      props: <String, dynamic>{
        'durationMs': durationMs,
        'running': props.containsKey('running')
            ? _requiredBooleanOrBindingValue(
                props['running'],
                path: '$path.props.running',
              )
            : true,
        if (props.containsKey('restartToken'))
          'restartToken': _requiredCountdownRestartToken(
            props['restartToken'],
            path: '$path.props.restartToken',
          ),
        if (remainingState != null) 'remainingState': remainingState,
        if (onComplete != null) 'onComplete': onComplete,
      },
      children: children,
    );
  }
}
