import 'dart:convert';

import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test(
    'appBar serializes custom slots, styling and actions deterministically',
    () {
      MpNode build() => Mp.appBar(
        leading: Mp.iconButton(
          'menu',
          semanticLabel: 'Menu',
          action: Mp.toast(message: 'Menu'),
        ),
        title: Mp.row(children: [Mp.icon('home'), Mp.text('My shop')]),
        actions: [
          Mp.iconButton(
            'search',
            semanticLabel: 'Search',
            action: Mp.navigation.openScreen('search'),
          ),
        ],
        backgroundColor: '#123456',
        foregroundColor: '#FFFFFF',
        shadowColor: '#80000000',
        centerTitle: true,
        height: 80,
        leadingWidth: 72,
        paddingHorizontal: 16,
        spacing: 4,
        elevation: 3,
      );
      final json = build().toJson();
      expect(json['type'], 'appBar');
      expect(json['props'], {
        'hasLeading': true,
        'actionCount': 1,
        'centerTitle': true,
        'height': 80,
        'leadingWidth': 72,
        'paddingHorizontal': 16,
        'spacing': 4,
        'elevation': 3,
        'backgroundColor': '#123456',
        'foregroundColor': '#FFFFFF',
        'shadowColor': '#80000000',
      });
      final children = json['children']! as List;
      expect(children.map((child) => (child as Map)['type']), [
        'iconButton',
        'row',
        'iconButton',
      ]);
      expect(
        ((children.last as Map)['props'] as Map)['action'],
        Mp.navigation.openScreen('search').toJson(),
      );
      expect(jsonEncode(json), jsonEncode(build().toJson()));
    },
  );

  test('appBar defaults contain only its supplied title', () {
    final json = Mp.appBar(title: Mp.text('Shop')).toJson();
    expect(json['props'], {
      'hasLeading': false,
      'actionCount': 0,
      'centerTitle': false,
      'height': 64,
      'leadingWidth': 56,
      'paddingHorizontal': 12,
      'spacing': 8,
      'elevation': 0,
    });
    expect(json['children'], [Mp.text('Shop').toJson()]);
  });

  test('appBar bounds styling numbers and requires literal hex colors', () {
    final numbers = <String, MpNode Function(num)>{
      'height': (value) => Mp.appBar(title: Mp.text('Shop'), height: value),
      'leadingWidth': (value) =>
          Mp.appBar(title: Mp.text('Shop'), leadingWidth: value),
      'paddingHorizontal': (value) =>
          Mp.appBar(title: Mp.text('Shop'), paddingHorizontal: value),
      'spacing': (value) => Mp.appBar(title: Mp.text('Shop'), spacing: value),
      'elevation': (value) =>
          Mp.appBar(title: Mp.text('Shop'), elevation: value),
    };
    for (final builder in numbers.values) {
      for (final invalid in [-1, 1000, double.infinity, double.nan]) {
        expect(() => builder(invalid), throwsArgumentError);
      }
    }
    expect(() => numbers['height']!(47), throwsArgumentError);
    for (final color in ['', 'white', '{{state.color}}', '#12345G']) {
      expect(
        () => Mp.appBar(title: Mp.text('Shop'), backgroundColor: color),
        throwsArgumentError,
      );
      expect(
        () => Mp.appBar(title: Mp.text('Shop'), foregroundColor: color),
        throwsArgumentError,
      );
      expect(
        () => Mp.appBar(title: Mp.text('Shop'), shadowColor: color),
        throwsArgumentError,
      );
    }
    expect(
      () => Mp.appBar(
        title: Mp.text('Shop'),
        actions: List.filled(5, Mp.icon('home')),
      ),
      throwsArgumentError,
    );
    expect(
      () => Mp.appBar(
        title: Mp.text('Shop'),
        height: 48,
        leadingWidth: 0,
        paddingHorizontal: 0,
        spacing: 0,
        elevation: 24,
      ),
      returnsNormally,
    );
    expect(
      () => Mp.appBar(
        title: Mp.text('Shop'),
        height: 160,
        leadingWidth: 256,
        paddingHorizontal: 48,
        spacing: 24,
      ),
      returnsNormally,
    );
  });

  test('icon button color can inherit toolbar styling or be explicit', () {
    final inherited = Mp.iconButton(
      'search',
      semanticLabel: 'Search',
      action: Mp.toast(message: 'Search'),
    ).toJson();
    expect(inherited['props'] as Map, isNot(contains('color')));
    final explicit = Mp.iconButton(
      'search',
      semanticLabel: 'Search',
      action: Mp.toast(message: 'Search'),
      color: '#ABCDEF',
    ).toJson();
    expect((explicit['props'] as Map)['color'], '#ABCDEF');
  });
}
