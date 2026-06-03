import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('MpProgram', () {
    test('serializes an Mp sample to deterministic JSON', () {
      final miniProgram = MpProgram(
        screens: <String, MpScreenBuilder>{
          'coupon_home': () => Mp.column(
            children: <MpNode>[
              Mp.heading('Publisher account'),
              Mp.text('Sign in to continue'),
              Mp.primaryButton(
                label: 'Sign in',
                action: Mp.auth.showEmailAuth(),
              ),
            ],
          ),
        },
      );

      expect(miniProgram.buildScreensJson(), <String, Object?>{
        'coupon_home': <String, Object?>{
          'schemaVersion': 1,
          'screenId': 'coupon_home',
          'root': <String, Object?>{
            'type': 'column',
            'props': <String, Object?>{},
            'children': <Object?>[
              <String, Object?>{
                'type': 'heading',
                'props': <String, Object?>{'data': 'Publisher account'},
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Sign in to continue'},
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'primaryButton',
                'props': <String, Object?>{
                  'action': <String, Object?>{
                    'type': 'auth.showEmailAuth',
                    'props': <String, Object?>{},
                  },
                  'label': 'Sign in',
                },
                'children': <Object?>[],
              },
            ],
          },
        },
      });
    });

    test('serializes runtime parity nodes and actions deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'coupon_home': () => Mp.column(
            children: <MpNode>[
              Mp.authBuilder(
                signedOut: Mp.primaryButton(
                  label: 'Sign in',
                  action: Mp.auth.showEmailAuth(),
                ),
                signedIn: Mp.secondaryButton(
                  label: 'Sign out',
                  action: Mp.auth.signOut(),
                ),
              ),
              Mp.backendBuilder(
                requestId: 'home',
                endpoint: 'home/bootstrap',
                child: Mp.text('{{backend.home.data.title}}'),
              ),
              Mp.pagedBackendBuilder(
                requestId: 'coupons',
                endpoint: 'coupons/page',
                limit: 10,
                itemTemplate: Mp.card(child: Mp.text('{{item.title}}')),
                loadMore: Mp.secondaryButton(
                  label: 'Load more',
                  action: Mp.backend.loadMore(requestId: 'coupons'),
                ),
              ),
              Mp.primaryButton(
                label: 'Details',
                action: Mp.navigation.openScreen('coupon_details'),
              ),
            ],
          ),
        },
      ).buildScreensJson()['coupon_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'authBuilder',
            'props': <String, Object?>{
              'signedIn': <String, Object?>{
                'type': 'secondaryButton',
                'props': <String, Object?>{
                  'action': <String, Object?>{
                    'type': 'auth.signOut',
                    'props': <String, Object?>{},
                  },
                  'label': 'Sign out',
                },
                'children': <Object?>[],
              },
              'signedOut': <String, Object?>{
                'type': 'primaryButton',
                'props': <String, Object?>{
                  'action': <String, Object?>{
                    'type': 'auth.showEmailAuth',
                    'props': <String, Object?>{},
                  },
                  'label': 'Sign in',
                },
                'children': <Object?>[],
              },
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'backendBuilder',
            'props': <String, Object?>{
              'child': <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{
                  'data': '{{backend.home.data.title}}',
                },
                'children': <Object?>[],
              },
              'endpoint': 'home/bootstrap',
              'method': 'GET',
              'requestId': 'home',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'pagedBackendBuilder',
            'props': <String, Object?>{
              'cursorParam': 'cursor',
              'endpoint': 'coupons/page',
              'hasMorePath': 'hasMore',
              'itemTemplate': <String, Object?>{
                'type': 'card',
                'props': <String, Object?>{},
                'children': <Object?>[
                  <String, Object?>{
                    'type': 'text',
                    'props': <String, Object?>{'data': '{{item.title}}'},
                    'children': <Object?>[],
                  },
                ],
              },
              'itemsPath': 'items',
              'limit': 10,
              'limitParam': 'limit',
              'loadMore': <String, Object?>{
                'type': 'secondaryButton',
                'props': <String, Object?>{
                  'action': <String, Object?>{
                    'type': 'backend.loadMore',
                    'props': <String, Object?>{
                      'cursorParam': 'cursor',
                      'hasMorePath': 'hasMore',
                      'itemsPath': 'items',
                      'limit': 20,
                      'limitParam': 'limit',
                      'nextCursorPath': 'nextCursor',
                      'requestId': 'coupons',
                    },
                  },
                  'label': 'Load more',
                },
                'children': <Object?>[],
              },
              'nextCursorPath': 'nextCursor',
              'requestId': 'coupons',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'primaryButton',
            'props': <String, Object?>{
              'action': <String, Object?>{
                'type': 'navigation.openScreen',
                'props': <String, Object?>{'screenId': 'coupon_details'},
              },
              'label': 'Details',
            },
            'children': <Object?>[],
          },
        ],
      });
    });
  });
}
