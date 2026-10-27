import 'dart:convert';

/// Host-only progress tracking. Revision changes alone are not evidence that an
/// action advanced the goal, and semantic node IDs can be recreated.
class PhoneAiProgress {
  PhoneAiProgress({required this.limit});
  final int limit;
  String? _previous;
  int _unchanged = 0;
  final Map<String, int> _visits = {};

  String? inspect(Map<String, dynamic> snapshot) {
    final visible = jsonEncode({
      'appId': snapshot['appId'],
      'screenId': snapshot['screenId'],
      'canGoBack': snapshot['canGoBack'],
      'nodes': [
        for (final node in (snapshot['nodes'] as List).cast<Map>())
          {
            for (final key in const [
              'role',
              'label',
              'value',
              'hint',
              'actions',
              'enabled',
              'selected',
              'checked',
              'protected',
            ])
              if (node[key] != null) key: node[key],
          },
      ],
    });
    _unchanged = visible == _previous ? _unchanged + 1 : 0;
    _previous = visible;
    if (_unchanged >= limit) {
      return 'Repeated actions made no visible progress. Check the screen before continuing.';
    }
    final visits = (_visits[visible] ?? 0) + 1;
    _visits[visible] = visits;
    if (visits > limit) {
      return 'The AI returned to the same screen repeatedly. Check the goal before continuing.';
    }
    return null;
  }
}
