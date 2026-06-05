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

    test('serializes core design widgets deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'design_home': () => Mp.column(
            children: <MpNode>[
              Mp.padding(
                all: 16,
                horizontal: 20,
                left: 8,
                child: Mp.text('Padded'),
              ),
              Mp.container(
                width: 120,
                height: 44,
                paddingAll: 8,
                paddingVertical: 10,
                paddingRight: 12,
                backgroundColor: '#FFFFFFFF',
                borderColor: '#E5E7EB',
                borderWidth: 1,
                borderRadius: 6,
                child: Mp.text('Box'),
              ),
              Mp.scrollView(
                paddingVertical: 4,
                child: Mp.column(children: <MpNode>[Mp.text('Scrollable')]),
              ),
              Mp.divider(thickness: 2, spacing: 10, color: '#D1D5DB'),
              Mp.icon(
                'settings',
                size: 24,
                color: '#FF0000',
                semanticLabel: 'Settings',
              ),
              Mp.listTile(
                title: 'Profile',
                subtitle: 'Manage account',
                leadingIcon: 'person',
                trailingIcon: 'chevronRight',
                badge: 'New',
                action: Mp.navigation.openScreen('profile'),
              ),
              Mp.chip(
                label: 'Featured',
                tone: 'success',
                leadingIcon: 'star',
                action: Mp.state.set('filter.featured', true),
              ),
              Mp.badge(label: 'Beta', tone: 'warning'),
            ],
          ),
        },
      ).buildScreensJson()['design_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'padding',
            'props': <String, Object?>{
              'padding': <String, Object?>{
                'bottom': 16,
                'left': 8,
                'right': 20,
                'top': 16,
              },
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Padded'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'container',
            'props': <String, Object?>{
              'backgroundColor': '#FFFFFFFF',
              'borderColor': '#E5E7EB',
              'borderRadius': 6,
              'borderWidth': 1,
              'height': 44,
              'padding': <String, Object?>{
                'bottom': 10,
                'left': 8,
                'right': 12,
                'top': 10,
              },
              'width': 120,
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Box'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'scrollView',
            'props': <String, Object?>{
              'padding': <String, Object?>{'bottom': 4, 'top': 4},
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'column',
                'props': <String, Object?>{},
                'children': <Object?>[
                  <String, Object?>{
                    'type': 'text',
                    'props': <String, Object?>{'data': 'Scrollable'},
                    'children': <Object?>[],
                  },
                ],
              },
            ],
          },
          <String, Object?>{
            'type': 'divider',
            'props': <String, Object?>{
              'color': '#D1D5DB',
              'spacing': 10,
              'thickness': 2,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'icon',
            'props': <String, Object?>{
              'color': '#FF0000',
              'name': 'settings',
              'semanticLabel': 'Settings',
              'size': 24,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'listTile',
            'props': <String, Object?>{
              'action': <String, Object?>{
                'type': 'navigation.openScreen',
                'props': <String, Object?>{'screenId': 'profile'},
              },
              'badge': 'New',
              'leadingIcon': 'person',
              'subtitle': 'Manage account',
              'title': 'Profile',
              'trailingIcon': 'chevronRight',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'chip',
            'props': <String, Object?>{
              'action': <String, Object?>{
                'type': 'state.set',
                'props': <String, Object?>{
                  'key': 'filter.featured',
                  'value': true,
                },
              },
              'label': 'Featured',
              'leadingIcon': 'star',
              'tone': 'success',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'badge',
            'props': <String, Object?>{'label': 'Beta', 'tone': 'warning'},
            'children': <Object?>[],
          },
        ],
      });
    });

    test('serializes form nodes and feedback actions deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'application_home': () => Mp.form(
            id: 'application',
            children: <MpNode>[
              Mp.textInput(
                name: 'full_name',
                label: 'Full name',
                hint: 'Use your legal name',
                required: true,
                minLength: 2,
                maxLength: 80,
              ),
              Mp.textArea(
                name: 'essay',
                label: 'Essay',
                minLines: 4,
                maxLines: 8,
                maxLength: 500,
              ),
              Mp.dropdown(
                name: 'program',
                label: 'Program',
                hint: 'Choose a program',
                options: const <MpOption>[
                  MpOption(value: 'stem', label: 'STEM'),
                  MpOption(value: 'arts', label: 'Arts'),
                ],
                initialValue: 'stem',
              ),
              Mp.radioGroup(
                name: 'level',
                label: 'Level',
                options: const <MpOption>[
                  MpOption(value: 'undergraduate', label: 'Undergraduate'),
                  MpOption(value: 'graduate', label: 'Graduate'),
                ],
                required: true,
              ),
              Mp.checkbox(
                name: 'terms',
                label: 'I confirm this application is accurate',
                requiredTrue: true,
              ),
              Mp.formSubmit(
                label: 'Submit application',
                endpoint: 'applications/submit',
                requestId: 'application_submit',
                onSuccess: Mp.toast(message: 'Submitted', durationMs: 1200),
                onError: Mp.dialog(
                  title: 'Submission failed',
                  message: '{{backend.application_submit.message}}',
                ),
              ),
            ],
          ),
        },
      ).buildScreensJson()['application_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'form',
        'props': <String, Object?>{'id': 'application'},
        'children': <Object?>[
          <String, Object?>{
            'type': 'textInput',
            'props': <String, Object?>{
              'name': 'full_name',
              'label': 'Full name',
              'hint': 'Use your legal name',
              'required': true,
              'minLength': 2,
              'maxLength': 80,
              'keyboardType': 'text',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'textArea',
            'props': <String, Object?>{
              'name': 'essay',
              'label': 'Essay',
              'maxLength': 500,
              'minLines': 4,
              'maxLines': 8,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'dropdown',
            'props': <String, Object?>{
              'name': 'program',
              'label': 'Program',
              'hint': 'Choose a program',
              'options': <Object?>[
                <String, Object?>{'label': 'STEM', 'value': 'stem'},
                <String, Object?>{'label': 'Arts', 'value': 'arts'},
              ],
              'initialValue': 'stem',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'radioGroup',
            'props': <String, Object?>{
              'name': 'level',
              'label': 'Level',
              'options': <Object?>[
                <String, Object?>{
                  'label': 'Undergraduate',
                  'value': 'undergraduate',
                },
                <String, Object?>{'label': 'Graduate', 'value': 'graduate'},
              ],
              'required': true,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'checkbox',
            'props': <String, Object?>{
              'name': 'terms',
              'label': 'I confirm this application is accurate',
              'requiredTrue': true,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'formSubmit',
            'props': <String, Object?>{
              'label': 'Submit application',
              'endpoint': 'applications/submit',
              'requestId': 'application_submit',
              'method': 'POST',
              'onSuccess': <String, Object?>{
                'type': 'ui.toast',
                'props': <String, Object?>{
                  'message': 'Submitted',
                  'durationMs': 1200,
                },
              },
              'onError': <String, Object?>{
                'type': 'ui.dialog',
                'props': <String, Object?>{
                  'title': 'Submission failed',
                  'message': '{{backend.application_submit.message}}',
                  'confirmLabel': 'OK',
                },
              },
            },
            'children': <Object?>[],
          },
        ],
      });
    });

    test(
      'serializes state, router, and sequence helpers deterministically',
      () {
        final screen = MpProgram(
          screens: <String, MpScreenBuilder>{
            'counter_home': () => Mp.column(
              children: <MpNode>[
                Mp.stateBuilder(
                  keys: const <String>['count', 'product.selected'],
                  child: Mp.text('{{state.count}}'),
                ),
                Mp.primaryButton(
                  label: 'Add',
                  action: Mp.action.sequence(<MpAction>[
                    Mp.state.put('product.selected', <String, Object?>{
                      'id': '{{item.id}}',
                    }),
                    Mp.state.increment('count', by: 2),
                    Mp.router.push(
                      'product_detail',
                      params: <String, Object?>{'productId': '{{item.id}}'},
                    ),
                  ]),
                ),
                Mp.secondaryButton(
                  label: 'Back',
                  action: Mp.router.pop(
                    result: const <String, Object?>{'saved': true},
                  ),
                ),
              ],
            ),
          },
        ).buildScreensJson()['counter_home']!;

        expect(screen['root'], <String, Object?>{
          'type': 'column',
          'props': <String, Object?>{},
          'children': <Object?>[
            <String, Object?>{
              'type': 'stateBuilder',
              'props': <String, Object?>{
                'child': <String, Object?>{
                  'type': 'text',
                  'props': <String, Object?>{'data': '{{state.count}}'},
                  'children': <Object?>[],
                },
                'keys': <Object?>['count', 'product.selected'],
              },
              'children': <Object?>[],
            },
            <String, Object?>{
              'type': 'primaryButton',
              'props': <String, Object?>{
                'action': <String, Object?>{
                  'type': 'sequence',
                  'props': <String, Object?>{
                    'steps': <Object?>[
                      <String, Object?>{
                        'type': 'state.put',
                        'props': <String, Object?>{
                          'key': 'product.selected',
                          'value': <String, Object?>{'id': '{{item.id}}'},
                        },
                      },
                      <String, Object?>{
                        'type': 'state.increment',
                        'props': <String, Object?>{'by': 2, 'key': 'count'},
                      },
                      <String, Object?>{
                        'type': 'router.push',
                        'props': <String, Object?>{
                          'params': <String, Object?>{
                            'productId': '{{item.id}}',
                          },
                          'screenId': 'product_detail',
                        },
                      },
                    ],
                  },
                },
                'label': 'Add',
              },
              'children': <Object?>[],
            },
            <String, Object?>{
              'type': 'secondaryButton',
              'props': <String, Object?>{
                'action': <String, Object?>{
                  'type': 'router.pop',
                  'props': <String, Object?>{
                    'result': <String, Object?>{'saved': true},
                  },
                },
                'label': 'Back',
              },
              'children': <Object?>[],
            },
          ],
        });
      },
    );
  });
}
