part of '../../../mp_screen_renderer.dart';

extension _MpControlFormNodeValidation on MpScreenValidator {
  _MpNode _parseButtonNode({
    required String type,
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'label',
      'action',
    }, path: '$path.props');
    _requiredString(props, 'label', path: '$path.props');
    final action = _parseAction(props['action'], path: '$path.props.action');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: type,
      props: <String, dynamic>{'label': props['label'], 'action': action},
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseStyledButtonNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'label',
      'action',
      'height',
      'backgroundColor',
      'foregroundColor',
      'borderColor',
      'borderWidth',
      'borderRadius',
      'fontSize',
      'fontWeight',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'button',
      props: <String, dynamic>{
        'label': _requiredString(props, 'label', path: '$path.props'),
        'action': _parseAction(props['action'], path: '$path.props.action'),
        'height': _requiredPositiveNumber(props, 'height', path: '$path.props'),
        'backgroundColor': _requiredHexColor(
          props,
          'backgroundColor',
          path: '$path.props',
        ),
        'foregroundColor': _requiredHexColor(
          props,
          'foregroundColor',
          path: '$path.props',
        ),
        'borderColor': _requiredHexColor(
          props,
          'borderColor',
          path: '$path.props',
        ),
        'borderWidth': _requiredNonNegativeNumber(
          props,
          'borderWidth',
          path: '$path.props',
        ),
        'borderRadius': _requiredNonNegativeNumber(
          props,
          'borderRadius',
          path: '$path.props',
        ),
        'fontSize': _requiredPositiveNumber(
          props,
          'fontSize',
          path: '$path.props',
        ),
        'fontWeight': _optionalTextWeight(
          props,
          'fontWeight',
          path: '$path.props',
        )!,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseIconButtonNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'semanticLabel',
      'action',
      'size',
      'iconSize',
      'color',
      'backgroundColor',
      'borderColor',
      'borderWidth',
      'borderRadius',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final size = _requiredPositiveNumber(props, 'size', path: '$path.props');
    final iconSize = _requiredPositiveNumber(
      props,
      'iconSize',
      path: '$path.props',
    );
    if (iconSize > size) {
      _fail(
        'Mp iconButton iconSize cannot exceed size.',
        path: '$path.props.iconSize',
      );
    }
    return _MpNode(
      type: 'iconButton',
      props: <String, dynamic>{
        'name': _requiredIconName(props, 'name', path: '$path.props'),
        'semanticLabel': _requiredString(
          props,
          'semanticLabel',
          path: '$path.props',
        ),
        'action': _parseAction(props['action'], path: '$path.props.action'),
        'size': size,
        'iconSize': iconSize,
        'color': _requiredHexColor(props, 'color', path: '$path.props'),
        'backgroundColor': _requiredHexColor(
          props,
          'backgroundColor',
          path: '$path.props',
        ),
        'borderColor': _requiredHexColor(
          props,
          'borderColor',
          path: '$path.props',
        ),
        'borderWidth': _requiredNonNegativeNumber(
          props,
          'borderWidth',
          path: '$path.props',
        ),
        'borderRadius': _requiredNonNegativeNumber(
          props,
          'borderRadius',
          path: '$path.props',
        ),
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseTextInputNode({
    required String type,
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'label',
      'hint',
      'initialValue',
      'required',
      'minLength',
      'maxLength',
      'obscureText',
      'keyboardType',
    }, path: '$path.props');
    final parsedProps = _parseTextInputProps(props, path: path);
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(type: type, props: parsedProps, children: const <_MpNode>[]);
  }

  _MpNode _parseSearchInputNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'stateKey',
      'targetState',
      'endpoint',
      'requestId',
      'queryParam',
      'limitParam',
      'method',
      'body',
      'label',
      'hint',
      'initialValue',
      'minLength',
      'limit',
      'debounceMs',
      'statusState',
      'errorState',
      'clearResultsBelowMinLength',
      'cacheTtlSeconds',
    }, path: '$path.props');
    final stateKey = _requiredStateKey(props, 'stateKey', path: '$path.props');
    final method =
        _optionalStableString(props, 'method', path: '$path.props') ?? 'GET';
    if (method != 'GET' && method != 'POST') {
      _fail(
        'Mp searchInput method must be GET or POST.',
        path: '$path.props.method',
      );
    }
    final body = _optionalMap(props['body'], path: '$path.props.body');
    _validateCacheValue(body, path: '$path.props.body');
    final minLength =
        _optionalNonNegativeInt(
          props['minLength'],
          path: '$path.props.minLength',
        ) ??
        2;
    final limit =
        _optionalSearchLimit(props['limit'], path: '$path.props.limit') ?? 20;
    final debounceMs =
        _optionalNonNegativeInt(
          props['debounceMs'],
          path: '$path.props.debounceMs',
        ) ??
        300;
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'searchInput',
      props: <String, dynamic>{
        'stateKey': stateKey,
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        'endpoint': _requiredStableString(
          props,
          'endpoint',
          path: '$path.props',
        ),
        'requestId':
            _optionalStableString(props, 'requestId', path: '$path.props') ??
            'search_${stateKey.replaceAll('.', '_')}',
        'queryParam':
            _optionalFieldName(props, 'queryParam', path: '$path.props') ?? 'q',
        'limitParam':
            _optionalFieldName(props, 'limitParam', path: '$path.props') ??
            'limit',
        'method': method,
        'body': body,
        'label': _requiredString(props, 'label', path: '$path.props'),
        if (props.containsKey('hint'))
          'hint': _requiredString(props, 'hint', path: '$path.props'),
        if (props.containsKey('initialValue'))
          'initialValue': _optionalStringLiteral(
            props['initialValue'],
            path: '$path.props.initialValue',
          ),
        'minLength': minLength,
        'limit': limit,
        'debounceMs': debounceMs,
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
        'clearResultsBelowMinLength':
            _optionalBool(
              props['clearResultsBelowMinLength'],
              path: '$path.props.clearResultsBelowMinLength',
            ) ??
            true,
        if (props.containsKey('cacheTtlSeconds'))
          'cacheTtlSeconds': _optionalPositiveInt(
            props['cacheTtlSeconds'],
            path: '$path.props.cacheTtlSeconds',
          ),
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseSearchFieldNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'stateKey',
      'label',
      'hint',
      'initialValue',
      'maxLength',
      'debounceMs',
      'onChanged',
      'onSubmitted',
      'showClearButton',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final maxLength = _boundedIntValue(
      props['maxLength'],
      path: '$path.props.maxLength',
      minimum: 1,
      maximum: 256,
    );
    final debounceMs = _boundedIntValue(
      props['debounceMs'],
      path: '$path.props.debounceMs',
      minimum: 0,
      maximum: 60000,
    );
    return _MpNode(
      type: 'searchField',
      props: <String, dynamic>{
        'stateKey': _requiredStateKey(props, 'stateKey', path: '$path.props'),
        'label': _requiredString(props, 'label', path: '$path.props'),
        if (props.containsKey('hint'))
          'hint': _requiredString(props, 'hint', path: '$path.props'),
        'initialValue': _optionalStringLiteral(
          props['initialValue'] ?? '',
          path: '$path.props.initialValue',
        ),
        'maxLength': maxLength,
        'debounceMs': debounceMs,
        if (props.containsKey('onChanged'))
          'onChanged': _parseAction(
            props['onChanged'],
            path: '$path.props.onChanged',
          ),
        if (props.containsKey('onSubmitted'))
          'onSubmitted': _parseAction(
            props['onSubmitted'],
            path: '$path.props.onSubmitted',
          ),
        'showClearButton': _requiredBoolValue(
          props['showClearButton'],
          path: '$path.props.showClearButton',
        ),
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseTextAreaNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'label',
      'hint',
      'initialValue',
      'required',
      'minLength',
      'maxLength',
      'minLines',
      'maxLines',
    }, path: '$path.props');
    final minLines =
        _optionalPositiveInt(props['minLines'], path: '$path.props.minLines') ??
        3;
    final maxLines =
        _optionalPositiveInt(props['maxLines'], path: '$path.props.maxLines') ??
        6;
    if (maxLines < minLines) {
      _fail(
        'Mp textArea maxLines must be greater than or equal to minLines.',
        path: '$path.props.maxLines',
      );
    }
    final parsedProps = <String, dynamic>{
      ..._parseTextInputProps(props, path: path, includeKeyboardType: false),
      'minLines': minLines,
      'maxLines': maxLines,
    };
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'textArea',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  Map<String, dynamic> _parseTextInputProps(
    Map<String, dynamic> props, {
    required String path,
    bool includeKeyboardType = true,
  }) {
    final minLength = _optionalNonNegativeInt(
      props['minLength'],
      path: '$path.props.minLength',
    );
    final maxLength = _optionalPositiveInt(
      props['maxLength'],
      path: '$path.props.maxLength',
    );
    if (minLength != null && maxLength != null && minLength > maxLength) {
      _fail(
        'Mp minLength must be less than or equal to maxLength.',
        path: '$path.props.minLength',
      );
    }
    String? initialValue;
    if (props.containsKey('initialValue')) {
      final rawInitialValue = props['initialValue'];
      if (rawInitialValue is! String) {
        _fail(
          'Mp "initialValue" must be a string.',
          path: '$path.props.initialValue',
        );
      }
      if (rawInitialValue.length > MpScreenValidator.maxLiteralTextLength) {
        _fail(
          'Mp string literal exceeds the maximum length.',
          path: '$path.props.initialValue',
          details: <String, dynamic>{
            'length': rawInitialValue.length,
            'maxLiteralTextLength': MpScreenValidator.maxLiteralTextLength,
          },
        );
      }
      initialValue = rawInitialValue;
    }
    final parsed = <String, dynamic>{
      'name': _requiredFieldName(props, 'name', path: '$path.props'),
      'label': _requiredString(props, 'label', path: '$path.props'),
      if (props.containsKey('hint'))
        'hint': _requiredString(props, 'hint', path: '$path.props'),
      if (props.containsKey('initialValue')) 'initialValue': initialValue,
      'required':
          _optionalBool(props['required'], path: '$path.props.required') ??
          false,
      if (minLength != null) 'minLength': minLength,
      if (maxLength != null) 'maxLength': maxLength,
    };
    if (includeKeyboardType) {
      final keyboardType =
          _optionalStableString(props, 'keyboardType', path: '$path.props') ??
          'text';
      if (!const <String>{
        'text',
        'email',
        'number',
        'phone',
        'url',
      }.contains(keyboardType)) {
        _fail(
          'Mp textInput keyboardType is unsupported.',
          path: '$path.props.keyboardType',
        );
      }
      parsed['keyboardType'] = keyboardType;
      parsed['obscureText'] =
          _optionalBool(
            props['obscureText'],
            path: '$path.props.obscureText',
          ) ??
          false;
    }
    return parsed;
  }

  _MpNode _parseChoiceNode({
    required String type,
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'label',
      'hint',
      'options',
      'initialValue',
      'required',
    }, path: '$path.props');
    final options = _parseOptions(
      props['options'],
      path: '$path.props.options',
    );
    final initialValue = props.containsKey('initialValue')
        ? _requiredStableString(props, 'initialValue', path: '$path.props')
        : null;
    if (initialValue != null &&
        !options.any((option) => option['value'] == initialValue)) {
      _fail(
        'Mp $type initialValue must match one option value.',
        path: '$path.props.initialValue',
      );
    }
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: type,
      props: <String, dynamic>{
        'name': _requiredFieldName(props, 'name', path: '$path.props'),
        'label': _requiredString(props, 'label', path: '$path.props'),
        if (props.containsKey('hint'))
          'hint': _requiredString(props, 'hint', path: '$path.props'),
        'options': options,
        if (initialValue != null) 'initialValue': initialValue,
        'required':
            _optionalBool(props['required'], path: '$path.props.required') ??
            false,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseCheckboxNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'label',
      'initialValue',
      'requiredTrue',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'checkbox',
      props: <String, dynamic>{
        'name': _requiredFieldName(props, 'name', path: '$path.props'),
        'label': _requiredString(props, 'label', path: '$path.props'),
        'initialValue':
            _optionalBool(
              props['initialValue'],
              path: '$path.props.initialValue',
            ) ??
            false,
        'requiredTrue':
            _optionalBool(
              props['requiredTrue'],
              path: '$path.props.requiredTrue',
            ) ??
            false,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseFormNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{'id'}, path: '$path.props');
    if (children.isEmpty) {
      _fail('Mp form must contain at least one child.', path: '$path.children');
    }
    return _MpNode(
      type: 'form',
      props: <String, dynamic>{
        'id': props.containsKey('id')
            ? _requiredFieldName(props, 'id', path: '$path.props')
            : 'form',
      },
      children: children,
    );
  }

  _MpNode _parseFormSubmitNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'label',
      'endpoint',
      'requestId',
      'method',
      'body',
      'cacheTtlSeconds',
      'onSuccess',
      'onError',
    }, path: '$path.props');
    final parsedProps = <String, dynamic>{
      'label': _requiredString(props, 'label', path: '$path.props'),
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
      if (props.containsKey('requestId'))
        'requestId': _requiredStableString(
          props,
          'requestId',
          path: '$path.props',
        ),
      'method':
          _optionalStableString(props, 'method', path: '$path.props') ?? 'POST',
      'body': _optionalMap(props['body'], path: '$path.props.body'),
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
      if (props.containsKey('onSuccess'))
        'onSuccess': _parseAction(
          props['onSuccess'],
          path: '$path.props.onSuccess',
        ),
      if (props.containsKey('onError'))
        'onError': _parseAction(props['onError'], path: '$path.props.onError'),
    };
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'formSubmit',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseStateBuilderNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'keys',
      'child',
    }, path: '$path.props');
    final parsedProps = <String, dynamic>{
      'keys': _parseStateKeys(props['keys'], path: '$path.props.keys'),
      ..._parseTemplateProps(
        props,
        const <String>{'child'},
        path: '$path.props',
        depth: depth,
        state: state,
      ),
    };
    if (!parsedProps.containsKey('child')) {
      _fail('Mp stateBuilder requires a child template.', path: '$path.props');
    }
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'stateBuilder',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }
}
