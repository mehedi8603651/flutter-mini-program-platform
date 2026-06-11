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

    test('serializes lightweight text styles deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'text_home': () => Mp.column(
            children: <MpNode>[
              Mp.text('Plain body'),
              Mp.text(
                'বাংলা লেখা এখানে',
                size: 16,
                color: '#111827',
                weight: 'semibold',
                align: 'center',
                maxLines: 2,
                overflow: 'ellipsis',
                softWrap: false,
                lineHeight: 1.4,
                locale: 'bn',
                variant: 'title',
              ),
              Mp.heading('Plain heading'),
              Mp.heading(
                'Styled heading',
                level: 3,
                size: 20,
                color: '#FF111827',
                weight: 'medium',
                align: 'right',
                maxLines: 1,
                overflow: 'fade',
                lineHeight: 1.1,
                textDirection: 'rtl',
                variant: 'section_title',
              ),
            ],
          ),
        },
      ).buildScreensJson()['text_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': 'Plain body'},
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{
              'align': 'center',
              'color': '#111827',
              'data': 'বাংলা লেখা এখানে',
              'lineHeight': 1.4,
              'locale': 'bn',
              'maxLines': 2,
              'overflow': 'ellipsis',
              'size': 16,
              'softWrap': false,
              'variant': 'title',
              'weight': 'semibold',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'heading',
            'props': <String, Object?>{'data': 'Plain heading'},
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'heading',
            'props': <String, Object?>{
              'align': 'right',
              'color': '#FF111827',
              'data': 'Styled heading',
              'level': 3,
              'lineHeight': 1.1,
              'maxLines': 1,
              'overflow': 'fade',
              'size': 20,
              'textDirection': 'rtl',
              'variant': 'section_title',
              'weight': 'medium',
            },
            'children': <Object?>[],
          },
        ],
      });
    });

    test('serializes lightweight themes deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'theme_home': () => Mp.column(
            children: <MpNode>[
              Mp.theme(child: Mp.text('Plain themed')),
              Mp.theme(
                colors: const <String, String>{
                  'text': '#111827',
                  'brandAccent': '#FF00AA',
                },
                typography: const <String, Map<String, Object?>>{
                  'title': <String, Object?>{
                    'size': 20,
                    'weight': 'bold',
                    'lineHeight': 1.25,
                    'color': 'text',
                  },
                  'caption': <String, Object?>{
                    'size': 12,
                    'weight': 'regular',
                    'lineHeight': 1.3,
                    'color': '#6B7280',
                  },
                },
                child: Mp.column(
                  children: <MpNode>[
                    Mp.text('Product title', variant: 'title'),
                    Mp.heading('Caption heading', level: 4, variant: 'caption'),
                  ],
                ),
              ),
            ],
          ),
        },
      ).buildScreensJson()['theme_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'theme',
            'props': <String, Object?>{},
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Plain themed'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'theme',
            'props': <String, Object?>{
              'colors': <String, Object?>{
                'brandAccent': '#FF00AA',
                'text': '#111827',
              },
              'typography': <String, Object?>{
                'caption': <String, Object?>{
                  'color': '#6B7280',
                  'lineHeight': 1.3,
                  'size': 12,
                  'weight': 'regular',
                },
                'title': <String, Object?>{
                  'color': 'text',
                  'lineHeight': 1.25,
                  'size': 20,
                  'weight': 'bold',
                },
              },
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'column',
                'props': <String, Object?>{},
                'children': <Object?>[
                  <String, Object?>{
                    'type': 'text',
                    'props': <String, Object?>{
                      'data': 'Product title',
                      'variant': 'title',
                    },
                    'children': <Object?>[],
                  },
                  <String, Object?>{
                    'type': 'heading',
                    'props': <String, Object?>{
                      'data': 'Caption heading',
                      'level': 4,
                      'variant': 'caption',
                    },
                    'children': <Object?>[],
                  },
                ],
              },
            ],
          },
        ],
      });
    });

    test('serializes async image nodes deterministically', () {
      const base64Image =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'image_home': () => Mp.column(
            children: <MpNode>[
              Mp.image(
                src: 'https://example.com/a.png',
                width: 120,
                height: 120,
                fit: MpImageFit.cover,
                semanticLabel: 'Product image',
                headers: const <String, String>{'x-image': 'product'},
                cacheKey: 'product_1',
              ),
              Mp.image(
                src: 'assets/logo.png',
                source: MpImageSource.asset,
                fit: MpImageFit.contain,
                alt: 'Logo asset',
              ),
              Mp.image(
                src: base64Image,
                source: MpImageSource.base64,
                fit: MpImageFit.none,
                placeholder: Mp.text('Loading image...'),
                error: Mp.text('Image failed'),
                fadeInDuration: const Duration(milliseconds: 80),
              ),
            ],
          ),
        },
      ).buildScreensJson()['image_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'image',
            'props': <String, Object?>{
              'cache': true,
              'cacheKey': 'product_1',
              'fadeInDurationMs': 200,
              'fit': 'cover',
              'headers': <String, Object?>{'x-image': 'product'},
              'height': 120.0,
              'semanticLabel': 'Product image',
              'source': 'auto',
              'src': 'https://example.com/a.png',
              'width': 120.0,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'image',
            'props': <String, Object?>{
              'alt': 'Logo asset',
              'cache': true,
              'fadeInDurationMs': 200,
              'fit': 'contain',
              'semanticLabel': 'Logo asset',
              'source': 'asset',
              'src': 'assets/logo.png',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'image',
            'props': <String, Object?>{
              'cache': true,
              'error': <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Image failed'},
                'children': <Object?>[],
              },
              'fadeInDurationMs': 80,
              'fit': 'none',
              'placeholder': <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Loading image...'},
                'children': <Object?>[],
              },
              'source': 'base64',
              'src': base64Image,
            },
            'children': <Object?>[],
          },
        ],
      });
    });

    test('serializes skeleton nodes deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'skeleton_home': () => Mp.column(
            children: <MpNode>[
              Mp.skeleton.box(),
              Mp.skeleton.box(
                width: 120,
                height: 120,
                radius: 10,
                colorToken: 'skeletonAccent',
              ),
              Mp.skeleton.text(width: 220),
              Mp.skeleton.circle(size: 48),
              Mp.skeleton.card(width: 320),
              Mp.skeleton.list(count: 5, width: 300),
            ],
          ),
        },
      ).buildScreensJson()['skeleton_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'skeleton',
            'props': <String, Object?>{'radius': 8.0, 'variant': 'box'},
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'skeleton',
            'props': <String, Object?>{
              'colorToken': 'skeletonAccent',
              'height': 120.0,
              'radius': 10.0,
              'variant': 'box',
              'width': 120.0,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'skeleton',
            'props': <String, Object?>{
              'height': 14.0,
              'radius': 4.0,
              'variant': 'text',
              'width': 220.0,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'skeleton',
            'props': <String, Object?>{'size': 48.0, 'variant': 'circle'},
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'skeleton',
            'props': <String, Object?>{
              'height': 160.0,
              'radius': 12.0,
              'variant': 'card',
              'width': 320.0,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'skeleton',
            'props': <String, Object?>{
              'count': 5,
              'itemHeight': 72.0,
              'radius': 8.0,
              'spacing': 12.0,
              'variant': 'list',
              'width': 300.0,
            },
            'children': <Object?>[],
          },
        ],
      });
    });

    test('serializes lazy section nodes deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'lazy_home': () => Mp.lazy.section(
            id: 'home_products',
            cacheKey: 'products_page_1',
            bucket: 'data',
            targetState: 'products',
            ttl: const Duration(days: 1),
            statusState: 'products_lazy_status',
            retry: 1,
            retryDelay: const Duration(milliseconds: 300),
            placeholder: Mp.skeleton.list(count: 4),
            error: Mp.text('Failed to load products'),
            actions: <MpAction>[
              Mp.backend.query(
                requestId: 'products_query',
                endpoint: '/products',
              ),
            ],
            child: Mp.text('{{state.products}}'),
          ),
        },
      ).buildScreensJson()['lazy_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'lazy',
        'props': <String, Object?>{
          'actions': <Object?>[
            <String, Object?>{
              'type': 'backend.query',
              'props': <String, Object?>{
                'endpoint': '/products',
                'method': 'GET',
                'requestId': 'products_query',
              },
            },
          ],
          'bucket': 'data',
          'cacheKey': 'products_page_1',
          'error': <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': 'Failed to load products'},
            'children': <Object?>[],
          },
          'id': 'home_products',
          'once': true,
          'placeholder': <String, Object?>{
            'type': 'skeleton',
            'props': <String, Object?>{
              'count': 4,
              'itemHeight': 72.0,
              'radius': 8.0,
              'spacing': 12.0,
              'variant': 'list',
            },
            'children': <Object?>[],
          },
          'refreshIfCached': false,
          'retry': 1,
          'retryDelayMs': 300,
          'statusState': 'products_lazy_status',
          'targetState': 'products',
          'ttlMs': 86400000,
        },
        'children': <Object?>[
          <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': '{{state.products}}'},
            'children': <Object?>[],
          },
        ],
      });
    });

    test('serializes lazy chunk nodes deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'lazy_chunk_home': () => Mp.lazy.chunk(
            id: 'home_rewards',
            cacheKeyPrefix: 'rewards_chunk',
            itemsState: 'rewards.items',
            cursorState: 'rewards.next_cursor',
            hasMoreState: 'rewards.has_more',
            statusState: 'rewards.status',
            ttl: const Duration(minutes: 5),
            retry: 1,
            retryDelay: const Duration(milliseconds: 250),
            placeholder: Mp.text('Loading rewards'),
            empty: Mp.text('No rewards'),
            error: Mp.text('Rewards failed'),
            loadingMore: Mp.text('Loading more rewards'),
            loadMore: Mp.secondaryButton(
              label: 'Load more rewards',
              action: Mp.lazy.loadMore(id: 'home_rewards'),
            ),
            end: Mp.text('No more rewards'),
            itemTemplate: Mp.text('{{item.title}}'),
            initialActions: <MpAction>[
              Mp.backend.loadMore(
                requestId: 'rewards',
                endpoint: '/rewards',
                limit: 10,
              ),
            ],
            loadMoreActions: <MpAction>[
              Mp.backend.loadMore(
                requestId: 'rewards',
                endpoint: '/rewards',
                limit: 10,
              ),
            ],
          ),
        },
      ).buildScreensJson()['lazy_chunk_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'lazyChunk',
        'props': <String, Object?>{
          'bucket': 'data',
          'cacheKeyPrefix': 'rewards_chunk',
          'cursorState': 'rewards.next_cursor',
          'empty': <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': 'No rewards'},
            'children': <Object?>[],
          },
          'end': <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': 'No more rewards'},
            'children': <Object?>[],
          },
          'error': <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': 'Rewards failed'},
            'children': <Object?>[],
          },
          'hasMoreState': 'rewards.has_more',
          'id': 'home_rewards',
          'initialActions': <Object?>[
            <String, Object?>{
              'type': 'backend.loadMore',
              'props': <String, Object?>{
                'cursorParam': 'cursor',
                'endpoint': '/rewards',
                'hasMorePath': 'hasMore',
                'itemsPath': 'items',
                'limit': 10,
                'limitParam': 'limit',
                'nextCursorPath': 'nextCursor',
                'requestId': 'rewards',
              },
            },
          ],
          'itemTemplate': <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': '{{item.title}}'},
            'children': <Object?>[],
          },
          'itemsState': 'rewards.items',
          'loadingMore': <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': 'Loading more rewards'},
            'children': <Object?>[],
          },
          'loadMoreActions': <Object?>[
            <String, Object?>{
              'type': 'backend.loadMore',
              'props': <String, Object?>{
                'cursorParam': 'cursor',
                'endpoint': '/rewards',
                'hasMorePath': 'hasMore',
                'itemsPath': 'items',
                'limit': 10,
                'limitParam': 'limit',
                'nextCursorPath': 'nextCursor',
                'requestId': 'rewards',
              },
            },
          ],
          'loadMore': <String, Object?>{
            'type': 'secondaryButton',
            'props': <String, Object?>{
              'action': <String, Object?>{
                'type': 'lazy.chunk.loadMore',
                'props': <String, Object?>{'id': 'home_rewards'},
              },
              'label': 'Load more rewards',
            },
            'children': <Object?>[],
          },
          'once': true,
          'placeholder': <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': 'Loading rewards'},
            'children': <Object?>[],
          },
          'refreshIfCached': false,
          'retry': 1,
          'retryDelayMs': 250,
          'statusState': 'rewards.status',
          'ttlMs': 300000,
        },
        'children': <Object?>[],
      });
    });

    test('serializes repeat and forEach nodes deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'area_home': () => Mp.column(
            children: <MpNode>[
              Mp.repeat(
                source: '{{state.area.results.items}}',
                itemTemplate: Mp.listTile(
                  title: '{{index}}. {{item.name}}',
                  subtitle: '{{item.lat}}, {{item.lon}}',
                ),
                empty: Mp.emptyState(title: 'No area found'),
                separator: Mp.divider(spacing: 0),
                spacing: 4,
                limit: 20,
              ),
              Mp.forEach(
                source: '{{backend.area_search.data.items}}',
                itemTemplate: Mp.text('{{item.name}}'),
              ),
            ],
          ),
        },
      ).buildScreensJson()['area_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'repeat',
            'props': <String, Object?>{
              'empty': <String, Object?>{
                'type': 'emptyState',
                'props': <String, Object?>{
                  'icon': 'info',
                  'title': 'No area found',
                },
                'children': <Object?>[],
              },
              'itemTemplate': <String, Object?>{
                'type': 'listTile',
                'props': <String, Object?>{
                  'subtitle': '{{item.lat}}, {{item.lon}}',
                  'title': '{{index}}. {{item.name}}',
                },
                'children': <Object?>[],
              },
              'limit': 20,
              'separator': <String, Object?>{
                'type': 'divider',
                'props': <String, Object?>{
                  'color': '#E5E7EB',
                  'spacing': 0,
                  'thickness': 1,
                },
                'children': <Object?>[],
              },
              'source': '{{state.area.results.items}}',
              'spacing': 4,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'repeat',
            'props': <String, Object?>{
              'itemTemplate': <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': '{{item.name}}'},
                'children': <Object?>[],
              },
              'limit': 100,
              'source': '{{backend.area_search.data.items}}',
              'spacing': 0,
            },
            'children': <Object?>[],
          },
        ],
      });
    });

    test('serializes backend search input nodes deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'area_home': () => Mp.column(
            children: <MpNode>[
              Mp.searchInput(
                stateKey: 'area.query',
                targetState: 'area.results',
                statusState: 'area.search_status',
                endpoint: '/areas/search',
                hint: 'Search area',
              ),
              Mp.search.input(
                stateKey: 'district.query',
                targetState: 'district.results',
                endpoint: '/districts/search',
                hint: 'Search district',
              ),
              Mp.searchInput(
                stateKey: 'product.query',
                targetState: 'product.results',
                errorState: 'product.search_error',
                endpoint: '/products/search',
                requestId: 'product_search',
                queryParam: 'term',
                limitParam: 'take',
                method: 'post',
                body: const <String, Object?>{'category': 'books'},
                label: 'Find product',
                initialValue: 'dart',
                minLength: 0,
                limit: 10,
                debounce: Duration.zero,
                clearResultsBelowMinLength: false,
                cacheTtlSeconds: 30,
              ),
            ],
          ),
        },
      ).buildScreensJson()['area_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'searchInput',
            'props': <String, Object?>{
              'debounceMs': 300,
              'endpoint': '/areas/search',
              'hint': 'Search area',
              'label': 'Search',
              'limit': 20,
              'limitParam': 'limit',
              'method': 'GET',
              'minLength': 2,
              'queryParam': 'q',
              'requestId': 'search_area_query',
              'stateKey': 'area.query',
              'statusState': 'area.search_status',
              'targetState': 'area.results',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'searchInput',
            'props': <String, Object?>{
              'debounceMs': 300,
              'endpoint': '/districts/search',
              'hint': 'Search district',
              'label': 'Search',
              'limit': 20,
              'limitParam': 'limit',
              'method': 'GET',
              'minLength': 2,
              'queryParam': 'q',
              'requestId': 'search_district_query',
              'stateKey': 'district.query',
              'targetState': 'district.results',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'searchInput',
            'props': <String, Object?>{
              'body': <String, Object?>{'category': 'books'},
              'cacheTtlSeconds': 30,
              'clearResultsBelowMinLength': false,
              'debounceMs': 0,
              'endpoint': '/products/search',
              'errorState': 'product.search_error',
              'initialValue': 'dart',
              'label': 'Find product',
              'limit': 10,
              'limitParam': 'take',
              'method': 'POST',
              'minLength': 0,
              'queryParam': 'term',
              'requestId': 'product_search',
              'stateKey': 'product.query',
              'targetState': 'product.results',
            },
            'children': <Object?>[],
          },
        ],
      });
    });

    test('serializes backend search namespace actions deterministically', () {
      final clear = Mp.search.clear(
        queryState: 'area.query',
        targetState: 'area.results',
        statusState: 'area.search_status',
        errorState: 'area.search_error',
      );
      final refresh = Mp.search.refresh(
        queryState: 'area.query',
        targetState: 'area.results',
        statusState: 'area.search_status',
        errorState: 'area.search_error',
        endpoint: '/areas/search',
      );
      final customRefresh = Mp.search.refresh(
        queryState: 'product.query',
        targetState: 'product.results',
        endpoint: '/products/search',
        requestId: 'product_search_refresh',
        queryParam: 'term',
        limitParam: 'take',
        method: 'POST',
        body: const <String, Object?>{'category': 'books'},
        limit: 10,
        itemsPath: 'data.items',
        nextCursorPath: 'data.cursor',
        hasMorePath: 'data.hasMore',
        cacheTtlSeconds: 30,
        skipWhenNoQuery: false,
      );
      final action = Mp.search.loadMore(
        queryState: 'area.query',
        targetState: 'area.results',
        statusState: 'area.search_status',
        errorState: 'area.search_error',
        endpoint: '/areas/search',
      );
      final custom = Mp.search.loadMore(
        queryState: 'product.query',
        targetState: 'product.results',
        endpoint: '/products/search',
        requestId: 'product_search_more',
        queryParam: 'term',
        cursorParam: 'after',
        limitParam: 'take',
        method: 'POST',
        body: const <String, Object?>{'category': 'books'},
        limit: 10,
        itemsPath: 'data.items',
        nextCursorPath: 'data.cursor',
        hasMorePath: 'data.hasMore',
        cacheTtlSeconds: 30,
        skipWhenNoQuery: false,
      );

      expect(clear.toJson(), <String, Object?>{
        'type': 'search.clear',
        'props': <String, Object?>{
          'errorState': 'area.search_error',
          'queryState': 'area.query',
          'statusState': 'area.search_status',
          'targetState': 'area.results',
        },
      });
      expect(refresh.toJson(), <String, Object?>{
        'type': 'search.refresh',
        'props': <String, Object?>{
          'endpoint': '/areas/search',
          'errorState': 'area.search_error',
          'hasMorePath': 'hasMore',
          'itemsPath': 'items',
          'limit': 20,
          'limitParam': 'limit',
          'method': 'GET',
          'nextCursorPath': 'nextCursor',
          'queryParam': 'q',
          'queryState': 'area.query',
          'requestId': 'search_area_query_refresh',
          'statusState': 'area.search_status',
          'targetState': 'area.results',
        },
      });
      expect(customRefresh.toJson(), <String, Object?>{
        'type': 'search.refresh',
        'props': <String, Object?>{
          'body': <String, Object?>{'category': 'books'},
          'cacheTtlSeconds': 30,
          'endpoint': '/products/search',
          'hasMorePath': 'data.hasMore',
          'itemsPath': 'data.items',
          'limit': 10,
          'limitParam': 'take',
          'method': 'POST',
          'nextCursorPath': 'data.cursor',
          'queryParam': 'term',
          'queryState': 'product.query',
          'requestId': 'product_search_refresh',
          'skipWhenNoQuery': false,
          'targetState': 'product.results',
        },
      });
      expect(action.toJson(), <String, Object?>{
        'type': 'search.loadMore',
        'props': <String, Object?>{
          'cursorParam': 'cursor',
          'endpoint': '/areas/search',
          'errorState': 'area.search_error',
          'hasMorePath': 'hasMore',
          'itemsPath': 'items',
          'limit': 20,
          'limitParam': 'limit',
          'method': 'GET',
          'nextCursorPath': 'nextCursor',
          'queryParam': 'q',
          'queryState': 'area.query',
          'requestId': 'search_area_query_load_more',
          'statusState': 'area.search_status',
          'targetState': 'area.results',
        },
      });
      expect(custom.toJson(), <String, Object?>{
        'type': 'search.loadMore',
        'props': <String, Object?>{
          'body': <String, Object?>{'category': 'books'},
          'cacheTtlSeconds': 30,
          'cursorParam': 'after',
          'endpoint': '/products/search',
          'hasMorePath': 'data.hasMore',
          'itemsPath': 'data.items',
          'limit': 10,
          'limitParam': 'take',
          'method': 'POST',
          'nextCursorPath': 'data.cursor',
          'queryParam': 'term',
          'queryState': 'product.query',
          'requestId': 'product_search_more',
          'skipWhenNoQuery': false,
          'targetState': 'product.results',
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

    test('serializes future display and layout widgets deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'future_home': () => Mp.column(
            children: <MpNode>[
              Mp.alert(
                title: 'Heads up',
                message: 'Review settings',
                tone: 'warning',
              ),
              Mp.avatar(initials: 'MH', size: 48, semanticLabel: 'Mehedi'),
              Mp.grid(
                columns: 3,
                spacing: 6,
                children: <MpNode>[
                  Mp.text('One'),
                  Mp.text('Two'),
                  Mp.text('Three'),
                ],
              ),
              Mp.wrap(
                spacing: 4,
                runSpacing: 6,
                children: <MpNode>[
                  Mp.chip(label: 'Fast'),
                  Mp.badge(label: 'New'),
                ],
              ),
              Mp.progress(
                value: 2,
                max: 5,
                label: 'Uploading',
                tone: 'success',
              ),
              Mp.emptyState(
                title: 'No coupons',
                message: 'Try again later',
                icon: 'search',
                actionLabel: 'Retry',
                action: Mp.state.set('empty.retry', true),
              ),
              Mp.section(
                title: 'Featured',
                subtitle: 'Curated for you',
                actionLabel: 'View all',
                action: Mp.state.set('section.more', true),
                child: Mp.text('Section body'),
              ),
            ],
          ),
        },
      ).buildScreensJson()['future_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'alert',
            'props': <String, Object?>{
              'icon': 'warning',
              'message': 'Review settings',
              'title': 'Heads up',
              'tone': 'warning',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'avatar',
            'props': <String, Object?>{
              'initials': 'MH',
              'semanticLabel': 'Mehedi',
              'size': 48,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'grid',
            'props': <String, Object?>{'columns': 3, 'spacing': 6},
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'One'},
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Two'},
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Three'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'wrap',
            'props': <String, Object?>{'runSpacing': 6, 'spacing': 4},
            'children': <Object?>[
              <String, Object?>{
                'type': 'chip',
                'props': <String, Object?>{'label': 'Fast', 'tone': 'neutral'},
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'badge',
                'props': <String, Object?>{'label': 'New', 'tone': 'info'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'progress',
            'props': <String, Object?>{
              'label': 'Uploading',
              'max': 5,
              'tone': 'success',
              'value': 2,
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'emptyState',
            'props': <String, Object?>{
              'action': <String, Object?>{
                'type': 'state.set',
                'props': <String, Object?>{'key': 'empty.retry', 'value': true},
              },
              'actionLabel': 'Retry',
              'icon': 'search',
              'message': 'Try again later',
              'title': 'No coupons',
            },
            'children': <Object?>[],
          },
          <String, Object?>{
            'type': 'section',
            'props': <String, Object?>{
              'action': <String, Object?>{
                'type': 'state.set',
                'props': <String, Object?>{
                  'key': 'section.more',
                  'value': true,
                },
              },
              'actionLabel': 'View all',
              'subtitle': 'Curated for you',
              'title': 'Featured',
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Section body'},
                'children': <Object?>[],
              },
            ],
          },
        ],
      });
    });

    test('serializes safe layout primitives deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'layout_home': () => Mp.column(
            children: <MpNode>[
              Mp.align(alignment: 'topRight', child: Mp.text('Aligned')),
              Mp.center(child: Mp.text('Centered')),
              Mp.row(
                children: <MpNode>[
                  Mp.text('Left'),
                  Mp.spacer(flex: 2),
                  Mp.text('Right'),
                ],
              ),
              Mp.listView(
                spacing: 6,
                paddingHorizontal: 4,
                paddingVertical: 2,
                children: <MpNode>[Mp.text('One'), Mp.text('Two')],
              ),
              Mp.safeArea(left: false, bottom: false, child: Mp.text('Safe')),
            ],
          ),
        },
      ).buildScreensJson()['layout_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'align',
            'props': <String, Object?>{'alignment': 'topRight'},
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Aligned'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'center',
            'props': <String, Object?>{},
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Centered'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'row',
            'props': <String, Object?>{},
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Left'},
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'spacer',
                'props': <String, Object?>{'flex': 2},
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Right'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'listView',
            'props': <String, Object?>{
              'padding': <String, Object?>{
                'bottom': 2,
                'left': 4,
                'right': 4,
                'top': 2,
              },
              'spacing': 6,
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'One'},
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Two'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'safeArea',
            'props': <String, Object?>{
              'bottom': false,
              'left': false,
              'right': true,
              'top': true,
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Safe'},
                'children': <Object?>[],
              },
            ],
          },
        ],
      });
    });

    test('serializes visual layout primitives deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'visual_home': () => Mp.column(
            children: <MpNode>[
              Mp.visibility(
                visible: false,
                maintainSize: true,
                child: Mp.text('Hidden'),
              ),
              Mp.opacity(
                opacity: 0.5,
                alwaysIncludeSemantics: true,
                child: Mp.text('Faded'),
              ),
              Mp.aspectRatio(aspectRatio: 2, child: Mp.text('Ratio')),
              Mp.stack(
                alignment: 'bottomRight',
                clip: false,
                children: <MpNode>[
                  Mp.text('Base'),
                  Mp.positioned(
                    top: 8,
                    right: 12,
                    width: 50,
                    height: 20,
                    child: Mp.badge(label: 'New'),
                  ),
                ],
              ),
              Mp.positioned(top: 4, child: Mp.text('Fallback')),
            ],
          ),
        },
      ).buildScreensJson()['visual_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'visibility',
            'props': <String, Object?>{
              'maintainSize': true,
              'maintainState': false,
              'visible': false,
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Hidden'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'opacity',
            'props': <String, Object?>{
              'alwaysIncludeSemantics': true,
              'opacity': 0.5,
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Faded'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'aspectRatio',
            'props': <String, Object?>{'aspectRatio': 2},
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Ratio'},
                'children': <Object?>[],
              },
            ],
          },
          <String, Object?>{
            'type': 'stack',
            'props': <String, Object?>{
              'alignment': 'bottomRight',
              'clip': false,
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Base'},
                'children': <Object?>[],
              },
              <String, Object?>{
                'type': 'positioned',
                'props': <String, Object?>{
                  'height': 20,
                  'right': 12,
                  'top': 8,
                  'width': 50,
                },
                'children': <Object?>[
                  <String, Object?>{
                    'type': 'badge',
                    'props': <String, Object?>{'label': 'New', 'tone': 'info'},
                    'children': <Object?>[],
                  },
                ],
              },
            ],
          },
          <String, Object?>{
            'type': 'positioned',
            'props': <String, Object?>{'top': 4},
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Fallback'},
                'children': <Object?>[],
              },
            ],
          },
        ],
      });
    });

    test('serializes flex sizing primitives deterministically', () {
      final screen = MpProgram(
        screens: <String, MpScreenBuilder>{
          'flex_home': () => Mp.column(
            children: <MpNode>[
              Mp.row(
                children: <MpNode>[
                  Mp.expanded(flex: 2, child: Mp.text('Expanded')),
                  Mp.flexible(
                    flex: 3,
                    fit: 'tight',
                    child: Mp.text('Flexible'),
                  ),
                ],
              ),
              Mp.flexible(child: Mp.text('Default flexible')),
            ],
          ),
        },
      ).buildScreensJson()['flex_home']!;

      expect(screen['root'], <String, Object?>{
        'type': 'column',
        'props': <String, Object?>{},
        'children': <Object?>[
          <String, Object?>{
            'type': 'row',
            'props': <String, Object?>{},
            'children': <Object?>[
              <String, Object?>{
                'type': 'expanded',
                'props': <String, Object?>{'flex': 2},
                'children': <Object?>[
                  <String, Object?>{
                    'type': 'text',
                    'props': <String, Object?>{'data': 'Expanded'},
                    'children': <Object?>[],
                  },
                ],
              },
              <String, Object?>{
                'type': 'flexible',
                'props': <String, Object?>{'fit': 'tight', 'flex': 3},
                'children': <Object?>[
                  <String, Object?>{
                    'type': 'text',
                    'props': <String, Object?>{'data': 'Flexible'},
                    'children': <Object?>[],
                  },
                ],
              },
            ],
          },
          <String, Object?>{
            'type': 'flexible',
            'props': <String, Object?>{'fit': 'loose', 'flex': 1},
            'children': <Object?>[
              <String, Object?>{
                'type': 'text',
                'props': <String, Object?>{'data': 'Default flexible'},
                'children': <Object?>[],
              },
            ],
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
