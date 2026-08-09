import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('responsive screen layout serializes deterministically', () {
    expect(
      Mp.page(
        breakpoints: const MpResponsiveBreakpoints(
          mediumMinWidth: 720,
          expandedMinWidth: 1100,
        ),
        child: Mp.constrainedContent(
          maxWidth: 960,
          paddingHorizontal: 20,
          child: Mp.responsive(
            compact: Mp.text('Compact'),
            medium: Mp.text('Medium'),
            expanded: Mp.text('Expanded'),
          ),
        ),
      ).toJson(),
      <String, Object?>{
        'type': 'page',
        'props': <String, Object?>{
          'breakpoints': <String, Object?>{
            'expandedMinWidth': 1100,
            'mediumMinWidth': 720,
          },
          'safeArea': true,
        },
        'children': <Object?>[
          <String, Object?>{
            'type': 'constrainedContent',
            'props': <String, Object?>{
              'maxWidth': 960,
              'paddingHorizontal': 20,
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'responsive',
                'props': <String, Object?>{
                  'hasExpanded': true,
                  'hasMedium': true,
                },
                'children': <Object?>[
                  _textNode('Compact'),
                  _textNode('Medium'),
                  _textNode('Expanded'),
                ],
              },
            ],
          },
        ],
      },
    );
  });

  test('responsive variants and adaptive grids keep bounded metadata', () {
    expect(
      Mp.responsive(
        compact: Mp.text('Compact'),
        expanded: Mp.text('Expanded'),
      ).toJson()['props'],
      <String, Object?>{'hasExpanded': true, 'hasMedium': false},
    );
    expect(
      Mp.grid(
        minItemWidth: 180,
        maxColumns: 4,
        spacing: 12,
        children: <MpNode>[Mp.text('One'), Mp.text('Two')],
      ).toJson()['props'],
      <String, Object?>{'maxColumns': 4, 'minItemWidth': 180, 'spacing': 12},
    );
  });

  test('responsive authoring rejects invalid dimensions and grid modes', () {
    expect(
      () => Mp.page(
        breakpoints: const MpResponsiveBreakpoints(
          mediumMinWidth: 840,
          expandedMinWidth: 600,
        ),
        child: Mp.text('Invalid'),
      ),
      throwsArgumentError,
    );
    expect(
      () => Mp.constrainedContent(child: Mp.text('Invalid'), maxWidth: 0),
      throwsArgumentError,
    );
    expect(
      () => Mp.grid(
        columns: 2,
        minItemWidth: 180,
        children: <MpNode>[Mp.text('Invalid')],
      ),
      throwsArgumentError,
    );
    expect(
      () => Mp.grid(maxColumns: 4, children: <MpNode>[Mp.text('Invalid')]),
      throwsArgumentError,
    );
  });
}

Map<String, Object?> _textNode(String data) {
  return <String, Object?>{
    'type': 'text',
    'props': <String, Object?>{'data': data},
    'children': <Object?>[],
  };
}
