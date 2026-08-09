import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('page and topBar serialize explicit responsive screen ownership', () {
    expect(
      Mp.page(
        backgroundColor: '#FF000000',
        child: Mp.topBar(
          leading: Mp.icon('arrowBack', semanticLabel: 'Back'),
          title: Mp.text('Editor', maxLines: 1, overflow: 'ellipsis'),
          actions: <MpNode>[
            Mp.button(
              label: 'SAVE',
              action: Mp.toast(message: 'Saved'),
            ),
          ],
          backgroundColor: '#FF303030',
        ),
      ).toJson(),
      <String, Object?>{
        'type': 'page',
        'props': <String, Object?>{
          'backgroundColor': '#FF000000',
          'safeArea': true,
        },
        'children': <Object?>[
          <String, Object?>{
            'type': 'topBar',
            'props': <String, Object?>{
              'actionCount': 1,
              'backgroundColor': '#FF303030',
              'hasLeading': true,
              'height': 64,
              'paddingHorizontal': 12,
              'spacing': 8,
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'icon',
                'props': <String, Object?>{
                  'name': 'arrowBack',
                  'semanticLabel': 'Back',
                  'size': 20,
                },
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{
                  'data': 'Editor',
                  'maxLines': 1,
                  'overflow': 'ellipsis',
                },
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'button',
                'props': <String, Object?>{
                  'action': <String, Object?>{
                    'type': 'ui.toast',
                    'props': <String, Object?>{
                      'message': 'Saved',
                      'durationMs': 2400,
                    },
                  },
                  'backgroundColor': '#252525',
                  'borderColor': '#252525',
                  'borderRadius': 8,
                  'borderWidth': 0,
                  'fontSize': 18,
                  'fontWeight': 'medium',
                  'foregroundColor': '#F5F5F5',
                  'height': 56,
                  'label': 'SAVE',
                },
                'children': <Object?>[],
              },
            ],
          },
        ],
      },
    );
  });

  test('topBar rejects dimensions and excessive actions', () {
    expect(
      () => Mp.topBar(title: Mp.text('Title'), height: 47),
      throwsArgumentError,
    );
    expect(
      () => Mp.topBar(
        title: Mp.text('Title'),
        actions: List<MpNode>.filled(5, Mp.text('Action')),
      ),
      throwsArgumentError,
    );
  });
}
