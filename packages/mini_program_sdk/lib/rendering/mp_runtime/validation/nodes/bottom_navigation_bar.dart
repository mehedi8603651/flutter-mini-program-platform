part of '../../../mp_screen_renderer.dart';

extension _MpBottomNavigationBarValidation on MpScreenValidator {
  _MpNode _parseBottomNavigationBarNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'items',
      'selectedIndex',
      'labelBehavior',
      'height',
      'elevation',
      'backgroundColor',
      'indicatorColor',
      'selectedItemColor',
      'unselectedItemColor',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final rawItems = props['items'];
    if (rawItems is! List || rawItems.length < 2 || rawItems.length > 5) {
      _fail(
        'Mp bottomNavigationBar requires two to five items.',
        path: '$path.props.items',
      );
    }
    final items = <Map<String, dynamic>>[];
    for (var index = 0; index < rawItems.length; index++) {
      final itemPath = '$path.props.items[$index]';
      final rawItem = rawItems[index];
      if (rawItem is! Map) {
        _fail('Mp navigation item must be an object.', path: itemPath);
      }
      final item = Map<String, dynamic>.from(rawItem);
      _validateObjectKeys(item, const {
        'icon',
        'selectedIcon',
        'label',
        'action',
        'enabled',
      }, path: itemPath);
      final label = _requiredString(item, 'label', path: itemPath);
      if (label.length > 512) {
        _fail(
          'Mp navigation label cannot exceed 512 characters.',
          path: '$itemPath.label',
        );
      }
      items.add(<String, dynamic>{
        'icon': _requiredIconName(item, 'icon', path: itemPath),
        if (item.containsKey('selectedIcon'))
          'selectedIcon': _requiredIconName(
            item,
            'selectedIcon',
            path: itemPath,
          ),
        'label': label,
        'enabled': _requiredBoolValue(
          item['enabled'],
          path: '$itemPath.enabled',
        ),
        'action': _parseAction(item['action'], path: '$itemPath.action'),
      });
    }
    final selectedIndex = props['selectedIndex'];
    if (selectedIndex is String &&
        selectedIndex.length <= 512 &&
        _MpBindingResolver.isSingleBindingExpression(selectedIndex)) {
      // Binding safety is checked recursively before node parsing.
    } else {
      _boundedIntValue(
        selectedIndex,
        path: '$path.props.selectedIndex',
        minimum: 0,
        maximum: items.length - 1,
      );
    }
    final behavior = _requiredStableString(
      props,
      'labelBehavior',
      path: '$path.props',
    );
    if (!const {
      'alwaysShow',
      'onlyShowSelected',
      'alwaysHide',
    }.contains(behavior)) {
      _fail(
        'Mp bottomNavigationBar labelBehavior is invalid.',
        path: '$path.props.labelBehavior',
      );
    }
    return _MpNode(
      type: 'bottomNavigationBar',
      props: <String, dynamic>{
        'items': items,
        'selectedIndex': selectedIndex,
        'labelBehavior': behavior,
        'height': _boundedNumber(
          props['height'],
          path: '$path.props.height',
          minimum: 64,
          maximum: 128,
        ),
        'elevation': _boundedNumber(
          props['elevation'],
          path: '$path.props.elevation',
          minimum: 0,
          maximum: 24,
        ),
        for (final color in [
          'backgroundColor',
          'indicatorColor',
          'selectedItemColor',
          'unselectedItemColor',
        ])
          if (props.containsKey(color))
            color: _requiredHexColor(props, color, path: '$path.props'),
      },
      children: const <_MpNode>[],
    );
  }
}
