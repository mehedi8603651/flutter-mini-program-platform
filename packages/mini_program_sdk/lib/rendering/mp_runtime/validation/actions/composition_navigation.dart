part of '../../../mp_screen_renderer.dart';

extension _MpCompositionNavigationActionValidation on MpScreenValidator {
  _MpAction _parseSequenceAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{'steps'}, path: '$path.props');
    final steps = props['steps'];
    if (steps is! List || steps.isEmpty) {
      _fail(
        'Mp sequence requires a non-empty steps array.',
        path: '$path.props.steps',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'steps': <_MpAction>[
          for (var index = 0; index < steps.length; index += 1)
            _parseAction(steps[index], path: '$path.props.steps[$index]'),
        ],
      },
    );
  }

  _MpAction _parseIfElseAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'condition',
      'then',
      'else',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'condition': _requiredBooleanOrBindingValue(
          props['condition'],
          path: '$path.props.condition',
        ),
        'then': _parseAction(props['then'], path: '$path.props.then'),
        'else': _parseAction(props['else'], path: '$path.props.else'),
      },
    );
  }

  _MpAction _parseActionCall(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{'name'}, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'name': _validateActionName(props['name'], path: '$path.props.name'),
      },
    );
  }

  String _validateActionName(Object? value, {required String path}) {
    if (value is! String || value.trim() != value) {
      _fail('Mp action name must be a stable string.', path: path);
    }
    if (_MpBindingResolver.containsBinding(value) ||
        !MpScreenValidator._actionNamePattern.hasMatch(value)) {
      _fail(
        'Mp action name must start with a lowercase letter and contain only letters, numbers, or underscores.',
        path: path,
        details: <String, dynamic>{'actionName': value},
      );
    }
    return value;
  }

  _MpAction _parseRouterScreenAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'screenId',
      'params',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'screenId': _requiredStableString(
          props,
          'screenId',
          path: '$path.props',
        ),
        'params': _optionalMap(props['params'], path: '$path.props.params'),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseRouterResultAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'result',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'result': _optionalMap(props['result'], path: '$path.props.result'),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseRouterPopToScreenAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'screenId',
      'result',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'screenId': _requiredStableString(
          props,
          'screenId',
          path: '$path.props',
        ),
        'result': _optionalMap(props['result'], path: '$path.props.result'),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseScreenNavigationAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'screenId',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'screenId': _requiredStableString(
          props,
          'screenId',
          path: '$path.props',
        ),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseEmptyNavigationAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }
}
