import 'dart:convert';

import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  MpBottomNavigationItem item(String label, int index) =>
      MpBottomNavigationItem(
        icon: 'home',
        label: label,
        action: Mp.state.set('shop.tab', index),
      );
  final items = [item('Home', 0), item('Orders', 1)];

  test('bottom navigation serializes explicit defaults deterministically', () {
    final node = Mp.bottomNavigationBar(items: items);
    expect(node.toJson(), {
      'type': 'bottomNavigationBar',
      'props': {
        'items': [
          for (var index = 0; index < 2; index++)
            {
              'icon': 'home',
              'label': index == 0 ? 'Home' : 'Orders',
              'action': {
                'type': 'state.set',
                'props': {'key': 'shop.tab', 'value': index},
              },
              'enabled': true,
            },
        ],
        'selectedIndex': 0,
        'labelBehavior': 'alwaysShow',
        'height': 80,
        'elevation': 0,
      },
      'children': [],
    });
    expect(
      jsonEncode(node.toJson()),
      jsonEncode(Mp.bottomNavigationBar(items: items).toJson()),
    );
  });

  test('bottom navigation accepts bindings, selected icons and styling', () {
    final node = Mp.bottomNavigationBar(
      selectedIndex: '{{state.shop.tab}}',
      items: [
        MpBottomNavigationItem(
          icon: 'home',
          selectedIcon: 'star',
          label: 'Home',
          action: Mp.state.set('shop.tab', 0),
        ),
        MpBottomNavigationItem(
          icon: 'history',
          label: 'Orders {{state.orders.count}}',
          enabled: false,
          action: Mp.state.set('shop.tab', 1),
        ),
      ],
      labelBehavior: 'onlyShowSelected',
      height: 96,
      elevation: 4,
      backgroundColor: '#123456',
      indicatorColor: '#223344',
      selectedItemColor: '#FFFFFF',
      unselectedItemColor: '#AABBCC',
    );
    expect(node.props['selectedIndex'], '{{state.shop.tab}}');
    expect(node.props['labelBehavior'], 'onlyShowSelected');
    expect((node.props['items'] as List).first['selectedIcon'], 'star');
    expect((node.props['items'] as List).last['enabled'], false);
    expect(node.props['selectedItemColor'], '#FFFFFF');
    expect(
      Mp.bottomNavigationBar(
        items: List.generate(5, (i) => item('Tab $i', i)),
        selectedIndex: 4,
      ).props['selectedIndex'],
      4,
    );
    expect(
      Mp.bottomNavigationBar(
        items: items,
        labelBehavior: 'alwaysHide',
      ).props['labelBehavior'],
      'alwaysHide',
    );
  });

  test('bottom navigation rejects invalid counts and selection values', () {
    for (final count in [0, 1, 6]) {
      expect(
        () => Mp.bottomNavigationBar(
          items: List.generate(count, (i) => item('Tab $i', i)),
        ),
        throwsArgumentError,
      );
    }
    for (final selected in <Object>[
      -1,
      2,
      0.0,
      true,
      '1',
      'prefix {{state.tab}}',
      '{{state.tab}',
      '{{state.${'x' * 512}}}',
    ]) {
      expect(
        () => Mp.bottomNavigationBar(items: items, selectedIndex: selected),
        throwsArgumentError,
        reason: '$selected',
      );
    }
  });

  test(
    'bottom navigation rejects invalid sizing, enums, colors and item content',
    () {
      for (final height in [63, 129, double.nan, double.infinity]) {
        expect(
          () => Mp.bottomNavigationBar(items: items, height: height),
          throwsArgumentError,
        );
      }
      for (final elevation in [-1, 25, double.nan, double.infinity]) {
        expect(
          () => Mp.bottomNavigationBar(items: items, elevation: elevation),
          throwsArgumentError,
        );
      }
      expect(
        () => Mp.bottomNavigationBar(items: items, labelBehavior: 'unknown'),
        throwsArgumentError,
      );
      expect(
        () => Mp.bottomNavigationBar(items: items, backgroundColor: 'red'),
        throwsArgumentError,
      );
      expect(
        () => Mp.bottomNavigationBar(
          items: items,
          indicatorColor: '{{state.color}}',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.bottomNavigationBar(items: items, selectedItemColor: '#12'),
        throwsArgumentError,
      );
      expect(
        () => Mp.bottomNavigationBar(items: items, unselectedItemColor: ''),
        throwsArgumentError,
      );
      for (final invalid in [
        MpBottomNavigationItem(
          icon: 'unknown',
          label: 'Home',
          action: Mp.state.clear(),
        ),
        MpBottomNavigationItem(
          icon: '{{state.icon}}',
          label: 'Home',
          action: Mp.state.clear(),
        ),
        MpBottomNavigationItem(
          icon: 'home',
          selectedIcon: 'unknown',
          label: 'Home',
          action: Mp.state.clear(),
        ),
        MpBottomNavigationItem(
          icon: 'home',
          label: ' ',
          action: Mp.state.clear(),
        ),
        MpBottomNavigationItem(
          icon: 'home',
          label: 'x' * 513,
          action: Mp.state.clear(),
        ),
      ]) {
        expect(
          () => Mp.bottomNavigationBar(items: [items.first, invalid]),
          throwsArgumentError,
        );
      }
    },
  );

  test('node snapshots its destination list', () {
    final mutable = [...items];
    final node = Mp.bottomNavigationBar(items: mutable);
    mutable.clear();
    expect(node.props['items'], hasLength(2));
  });
}
