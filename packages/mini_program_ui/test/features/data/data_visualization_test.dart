import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('artifact data actions', () {
    test('serialize load and search actions', () {
      expect(
        Mp.data
            .loadJsonAsset(
              id: 'bd_locations',
              asset: 'data/bd_locations.json',
              ttl: const Duration(days: 30),
              statusState: 'location.resource_status',
              errorState: 'location.resource_error',
              requestId: 'load-locations',
            )
            .toJson(),
        <String, Object?>{
          'type': 'data.loadJsonAsset',
          'props': <String, Object?>{
            'asset': 'data/bd_locations.json',
            'errorState': 'location.resource_error',
            'forceRefresh': false,
            'id': 'bd_locations',
            'requestId': 'load-locations',
            'statusState': 'location.resource_status',
            'ttlMs': const Duration(days: 30).inMilliseconds,
          },
        },
      );

      expect(
        Mp.data
            .search(
              resourceId: 'bd_locations',
              query: '{{state.location.query}}',
              fields: const <String>['name', 'district.name'],
              itemsPath: 'locations',
              targetState: 'location.results',
            )
            .toJson(),
        <String, Object?>{
          'type': 'data.search',
          'props': <String, Object?>{
            'fields': <Object?>['name', 'district.name'],
            'itemsPath': 'locations',
            'limit': 20,
            'minQueryLength': 2,
            'query': '{{state.location.query}}',
            'resourceId': 'bd_locations',
            'targetState': 'location.results',
          },
        },
      );
    });

    test('rejects unsafe resources and invalid search options', () {
      expect(
        () => Mp.data.loadJsonAsset(id: 'places', asset: '../places.json'),
        throwsArgumentError,
      );
      expect(
        () => Mp.data.loadJsonAsset(
          id: 'places',
          asset: 'https://example.com/places.json',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.data.search(
          resourceId: 'places',
          query: 'dhaka',
          fields: const <String>[],
          targetState: 'location.results',
        ),
        throwsArgumentError,
      );
    });
  });

  group('data presentation widgets', () {
    test('serialize controlled search and horizontal collections', () {
      final action = Mp.data.search(
        resourceId: 'places',
        query: '{{state.location.query}}',
        fields: const <String>['name'],
        targetState: 'location.results',
      );
      final search = Mp.searchField(
        stateKey: 'location.query',
        hint: 'Dhaka',
        onChanged: action,
        onSubmitted: action,
      );
      expect(search.type, 'searchField');
      expect(search.props['stateKey'], 'location.query');
      expect(search.props['debounceMs'], 300);
      expect(search.props['onChanged'], isA<Map<String, Object?>>());

      final list = Mp.listView(
        direction: 'horizontal',
        height: 150,
        spacing: 12,
        children: <MpNode>[Mp.text('One'), Mp.text('Two')],
      );
      expect(list.props, containsPair('direction', 'horizontal'));
      expect(list.props, containsPair('height', 150));

      final repeat = Mp.repeat(
        source: '{{state.items}}',
        direction: 'horizontal',
        height: 120,
        itemTemplate: Mp.text('{{item.name}}'),
      );
      expect(repeat.props, containsPair('direction', 'horizontal'));
      expect(repeat.props, containsPair('height', 120));
    });

    test('serializes line chart and refresh root', () {
      final chart = Mp.lineChart(
        source: '{{state.forecast.hourly}}',
        valueField: 'temperature',
        labelField: 'time.label',
        unit: 'C',
        empty: Mp.text('No data'),
      );
      expect(chart.type, 'lineChart');
      expect(chart.props, containsPair('maxPoints', 200));
      expect(chart.props['empty'], isA<Map<String, Object?>>());

      final refresh = Mp.refreshIndicator(
        action: Mp.action.call('refreshForecast'),
        child: chart,
        semanticsLabel: 'Refresh forecast',
      );
      expect(refresh.type, 'refreshIndicator');
      expect(refresh.children, hasLength(1));
      expect(refresh.props['action'], isA<Map<String, Object?>>());
    });

    test('rejects invalid collection and chart bounds', () {
      expect(
        () => Mp.listView(
          direction: 'horizontal',
          children: <MpNode>[Mp.text('One')],
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.lineChart(
          source: '{{state.values}}',
          valueField: 'value',
          height: 20,
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.lineChart(
          source: '{{state.values}}',
          valueField: 'value',
          minY: 10,
          maxY: 5,
        ),
        throwsArgumentError,
      );
    });
  });
}
