part of '../mp_screen_renderer_test.dart';

const MiniProgramManifest _mpManifest = MiniProgramManifest(
  id: 'coupon',
  version: '1.0.0',
  entry: 'coupon_home',
  contractVersion: '1.0.0',
  sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
  requiredCapabilities: <CapabilityId>[CapabilityIds.auth],
  screenFormat: MiniProgramScreenFormats.mp,
  screenSchemaVersion: 1,
);

Map<String, dynamic> _uiGeneratedScreen() {
  final miniProgram = MpProgram(
    screens: <String, MpScreenBuilder>{
      'coupon_home': () => Mp.column(
        children: <MpNode>[
          Mp.heading('Publisher account'),
          Mp.text('Sign in to continue'),
          Mp.primaryButton(label: 'Sign in', action: Mp.auth.showEmailAuth()),
        ],
      ),
    },
  );
  return _jsonMap(miniProgram.buildScreensJson()['coupon_home']!);
}

Map<String, dynamic> _screenWith(void Function(Map<String, dynamic>) mutate) {
  final json = _uiGeneratedScreen();
  mutate(json);
  return json;
}

Map<String, dynamic> _cacheActionScreen(
  String type,
  Map<String, dynamic> props,
) {
  return _screenWith((json) {
    json['root'] = <String, dynamic>{
      'type': 'primaryButton',
      'props': <String, dynamic>{
        'label': 'Run cache',
        'action': <String, dynamic>{'type': type, 'props': props},
      },
      'children': <Object?>[],
    };
  });
}

Map<String, dynamic> _searchInputJson(
  Map<String, dynamic> props, {
  List<Object?> children = const <Object?>[],
}) {
  return <String, dynamic>{
    'type': 'searchInput',
    'props': <String, dynamic>{
      'stateKey': 'area.query',
      'targetState': 'area.results',
      'endpoint': '/areas/search',
      'requestId': 'area_search',
      'queryParam': 'q',
      'limitParam': 'limit',
      'method': 'GET',
      'body': <String, dynamic>{},
      'label': 'Search area',
      'minLength': 2,
      'limit': 20,
      'debounceMs': 300,
      ...props,
    },
    'children': children,
  };
}

Map<String, dynamic> _searchLoadMoreActionJson(Map<String, dynamic> props) {
  return <String, dynamic>{
    'type': 'search.loadMore',
    'props': <String, dynamic>{
      'queryState': 'area.query',
      'targetState': 'area.results',
      'endpoint': '/areas/search',
      'requestId': 'area_search_more',
      'queryParam': 'q',
      'cursorParam': 'cursor',
      'limitParam': 'limit',
      'method': 'GET',
      'body': <String, dynamic>{},
      'limit': 20,
      'itemsPath': 'items',
      'nextCursorPath': 'nextCursor',
      'hasMorePath': 'hasMore',
      ...props,
    },
  };
}

Map<String, dynamic> _searchClearActionJson(Map<String, dynamic> props) {
  return <String, dynamic>{
    'type': 'search.clear',
    'props': <String, dynamic>{
      'queryState': 'area.query',
      'targetState': 'area.results',
      ...props,
    },
  };
}

Map<String, dynamic> _searchRefreshActionJson(Map<String, dynamic> props) {
  return <String, dynamic>{
    'type': 'search.refresh',
    'props': <String, dynamic>{
      'queryState': 'area.query',
      'targetState': 'area.results',
      'endpoint': '/areas/search',
      'requestId': 'area_search_refresh',
      'queryParam': 'q',
      'limitParam': 'limit',
      'method': 'GET',
      'body': <String, dynamic>{},
      'limit': 20,
      'itemsPath': 'items',
      'nextCursorPath': 'nextCursor',
      'hasMorePath': 'hasMore',
      ...props,
    },
  };
}

Map<String, dynamic> _actionButtonJson(Map<String, dynamic> action) {
  return <String, dynamic>{
    'type': 'secondaryButton',
    'props': <String, dynamic>{'label': 'Run', 'action': action},
    'children': <Object?>[],
  };
}

Map<String, dynamic> _searchScreenJson({
  Duration debounce = const Duration(milliseconds: 300),
  bool includeError = false,
}) {
  final miniProgram = MpProgram(
    screens: <String, MpScreenBuilder>{
      'coupon_home': () => Mp.column(
        children: <MpNode>[
          Mp.searchInput(
            stateKey: 'area.query',
            targetState: 'area.results',
            statusState: 'area.search_status',
            errorState: includeError ? 'area.search_error' : null,
            endpoint: '/areas/search',
            debounce: debounce,
            minLength: 1,
          ),
          Mp.stateBuilder(
            keys: <String>[
              'area.results',
              'area.search_status',
              if (includeError) 'area.search_error',
            ],
            child: Mp.column(
              children: <MpNode>[
                Mp.text('Status: {{state.area.search_status}}'),
                if (includeError)
                  Mp.text('Error: {{state.area.search_error.message}}'),
                Mp.repeat(
                  source: '{{state.area.results.items}}',
                  itemTemplate: Mp.text('{{item.name}}'),
                ),
              ],
            ),
          ),
        ],
      ),
    },
  );
  return _jsonMap(miniProgram.buildScreensJson()['coupon_home']!);
}

Map<String, dynamic> _searchLoadMoreScreenJson() {
  final miniProgram = MpProgram(
    screens: <String, MpScreenBuilder>{
      'coupon_home': () => Mp.column(
        children: <MpNode>[
          Mp.stateBuilder(
            keys: const <String>[
              'area.results',
              'area.search_status',
              'area.search_error',
            ],
            child: Mp.column(
              children: <MpNode>[
                Mp.text('Status: {{state.area.search_status}}'),
                Mp.text('Error: {{state.area.search_error.message}}'),
                Mp.repeat(
                  source: '{{state.area.results.items}}',
                  itemTemplate: Mp.text('{{item.name}}'),
                ),
              ],
            ),
          ),
          Mp.secondaryButton(
            label: 'Load more',
            action: Mp.search.loadMore(
              queryState: 'area.query',
              targetState: 'area.results',
              statusState: 'area.search_status',
              errorState: 'area.search_error',
              endpoint: '/areas/search?country=bd',
              limit: 2,
            ),
          ),
        ],
      ),
    },
  );
  return _jsonMap(miniProgram.buildScreensJson()['coupon_home']!);
}

Map<String, dynamic> _lazySectionScreen({
  required String id,
  MpNode? child,
  List<MpAction> actions = const <MpAction>[],
  MpNode? placeholder,
  MpNode? error,
  bool once = true,
  String? statusState,
  String? cacheKey,
  String bucket = 'data',
  String? targetState,
  Duration? ttl,
  bool refreshIfCached = false,
  int retry = 0,
  Duration retryDelay = const Duration(milliseconds: 300),
}) {
  final miniProgram = MpProgram(
    screens: <String, MpScreenBuilder>{
      'coupon_home': () => Mp.lazy.section(
        id: id,
        child: child ?? Mp.text('{{state.products.title}}'),
        actions: actions,
        placeholder: placeholder,
        error: error,
        once: once,
        statusState: statusState,
        cacheKey: cacheKey,
        bucket: bucket,
        targetState: targetState,
        ttl: ttl,
        refreshIfCached: refreshIfCached,
        retry: retry,
        retryDelay: retryDelay,
      ),
    },
  );
  return _jsonMap(miniProgram.buildScreensJson()['coupon_home']!);
}

Map<String, dynamic> _lazyChunkScreen({
  String id = 'rewards_chunk',
  List<MpAction>? initialActions,
  List<MpAction>? loadMoreActions,
  MpNode? itemTemplate,
  String itemsState = 'rewards.items',
  String? cursorState = 'rewards.next_cursor',
  String? hasMoreState = 'rewards.has_more',
  String? statusState = 'rewards.status',
  String? cacheKeyPrefix,
  MpNode? placeholder,
  MpNode? empty,
  MpNode? error,
  MpNode? loadingMore,
  MpNode? loadMore,
  MpNode? end,
}) {
  final miniProgram = MpProgram(
    screens: <String, MpScreenBuilder>{
      'coupon_home': () => Mp.lazy.chunk(
        id: id,
        itemTemplate: itemTemplate ?? Mp.text('{{item.title}}'),
        initialActions:
            initialActions ??
            <MpAction>[
              Mp.backend.loadMore(
                requestId: 'rewards',
                endpoint: '/rewards',
                limit: 1,
              ),
            ],
        loadMoreActions:
            loadMoreActions ??
            <MpAction>[
              Mp.backend.loadMore(
                requestId: 'rewards',
                endpoint: '/rewards',
                limit: 1,
              ),
            ],
        itemsState: itemsState,
        cursorState: cursorState,
        hasMoreState: hasMoreState,
        statusState: statusState,
        cacheKeyPrefix: cacheKeyPrefix,
        placeholder: placeholder ?? Mp.text('Loading rewards'),
        empty: empty ?? Mp.text('No rewards'),
        error: error ?? Mp.text('Rewards failed'),
        loadingMore: loadingMore ?? Mp.text('Loading more rewards'),
        loadMore:
            loadMore ??
            Mp.secondaryButton(
              label: 'Load more rewards',
              action: Mp.lazy.loadMore(id: id),
            ),
        end: end ?? Mp.text('No more rewards'),
      ),
    },
  );
  return _jsonMap(miniProgram.buildScreensJson()['coupon_home']!);
}

Map<String, dynamic> _jsonMap(Map<String, Object?> json) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map);
}

Map<String, dynamic> _jsonAction(MpAction action) {
  return Map<String, dynamic>.from(
    jsonDecode(jsonEncode(action.toJson())) as Map,
  );
}

const Map<String, dynamic> _uiGeneratedScreenConst = <String, dynamic>{
  'schemaVersion': 1,
  'screenId': 'coupon_home',
  'root': <String, dynamic>{
    'type': 'column',
    'props': <String, dynamic>{},
    'children': <Object?>[
      <String, dynamic>{
        'type': 'primaryButton',
        'props': <String, dynamic>{
          'label': 'Sign in',
          'action': <String, dynamic>{
            'type': 'auth.showEmailAuth',
            'props': <String, dynamic>{},
          },
        },
        'children': <Object?>[],
      },
    ],
  },
};

const Map<String, dynamic> _authBuilderScreen = <String, dynamic>{
  'schemaVersion': 1,
  'screenId': 'coupon_home',
  'root': <String, dynamic>{
    'type': 'authBuilder',
    'props': <String, dynamic>{
      'signedOut': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': 'Signed out'},
        'children': <Object?>[],
      },
      'signedIn': <String, dynamic>{
        'type': 'column',
        'props': <String, dynamic>{},
        'children': <Object?>[
          <String, dynamic>{
            'type': 'text',
            'props': <String, dynamic>{
              'data': 'Signed in as {{auth.user.email}}',
            },
            'children': <Object?>[],
          },
          <String, dynamic>{
            'type': 'secondaryButton',
            'props': <String, dynamic>{
              'label': 'Sign out',
              'action': <String, dynamic>{
                'type': 'auth.signOut',
                'props': <String, dynamic>{},
              },
            },
            'children': <Object?>[],
          },
        ],
      },
    },
    'children': <Object?>[],
  },
};

const Map<String, dynamic> _backendBuilderScreen = <String, dynamic>{
  'schemaVersion': 1,
  'screenId': 'coupon_home',
  'root': <String, dynamic>{
    'type': 'backendBuilder',
    'props': <String, dynamic>{
      'requestId': 'home',
      'endpoint': 'home/bootstrap',
      'loading': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': 'Loading backend'},
        'children': <Object?>[],
      },
      'child': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': '{{backend.home.data.title}}'},
        'children': <Object?>[],
      },
    },
    'children': <Object?>[],
  },
};

const Map<String, dynamic> _pagedBuilderScreen = <String, dynamic>{
  'schemaVersion': 1,
  'screenId': 'coupon_home',
  'root': <String, dynamic>{
    'type': 'pagedBackendBuilder',
    'props': <String, dynamic>{
      'requestId': 'coupons',
      'endpoint': 'coupons/page',
      'limit': 1,
      'loading': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': 'Loading coupons'},
        'children': <Object?>[],
      },
      'itemTemplate': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': '{{item.title}}'},
        'children': <Object?>[],
      },
      'loadingMore': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': 'Loading more coupons'},
        'children': <Object?>[],
      },
      'error': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': '{{backend.coupons.message}}'},
        'children': <Object?>[],
      },
      'loadMore': <String, dynamic>{
        'type': 'secondaryButton',
        'props': <String, dynamic>{
          'label': 'Load more',
          'action': <String, dynamic>{
            'type': 'backend.loadMore',
            'props': <String, dynamic>{'requestId': 'coupons'},
          },
        },
        'children': <Object?>[],
      },
      'end': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': 'No more coupons'},
        'children': <Object?>[],
      },
    },
    'children': <Object?>[],
  },
};

const Map<String, dynamic> _navigationScreen = <String, dynamic>{
  'schemaVersion': 1,
  'screenId': 'coupon_home',
  'root': <String, dynamic>{
    'type': 'primaryButton',
    'props': <String, dynamic>{
      'label': 'Open details',
      'action': <String, dynamic>{
        'type': 'navigation.openScreen',
        'props': <String, dynamic>{'screenId': 'coupon_details'},
      },
    },
    'children': <Object?>[],
  },
};

const Map<String, dynamic> _formScreen = <String, dynamic>{
  'schemaVersion': 1,
  'screenId': 'coupon_home',
  'root': <String, dynamic>{
    'type': 'form',
    'props': <String, dynamic>{'id': 'application'},
    'children': <Object?>[
      <String, dynamic>{
        'type': 'textInput',
        'props': <String, dynamic>{
          'name': 'full_name',
          'label': 'Full name',
          'hint': 'Use your legal name',
          'required': true,
          'minLength': 2,
          'keyboardType': 'text',
        },
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'textArea',
        'props': <String, dynamic>{
          'name': 'essay',
          'label': 'Essay',
          'maxLength': 500,
          'minLines': 3,
          'maxLines': 6,
        },
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'dropdown',
        'props': <String, dynamic>{
          'name': 'program',
          'label': 'Program',
          'hint': 'Choose a program',
          'required': true,
          'options': <Object?>[
            <String, dynamic>{'value': 'stem', 'label': 'STEM'},
            <String, dynamic>{'value': 'arts', 'label': 'Arts'},
          ],
        },
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'radioGroup',
        'props': <String, dynamic>{
          'name': 'level',
          'label': 'Level',
          'required': true,
          'options': <Object?>[
            <String, dynamic>{
              'value': 'undergraduate',
              'label': 'Undergraduate',
            },
            <String, dynamic>{'value': 'graduate', 'label': 'Graduate'},
          ],
        },
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'checkbox',
        'props': <String, dynamic>{
          'name': 'terms',
          'label': 'I confirm this application is accurate',
          'requiredTrue': true,
        },
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'formSubmit',
        'props': <String, dynamic>{
          'label': 'Submit application',
          'endpoint': 'applications/submit',
          'method': 'POST',
          'onSuccess': <String, dynamic>{
            'type': 'ui.toast',
            'props': <String, dynamic>{'message': 'Submitted', 'durationMs': 1},
          },
        },
        'children': <Object?>[],
      },
    ],
  },
};

const Map<String, dynamic> _feedbackScreen = <String, dynamic>{
  'schemaVersion': 1,
  'screenId': 'coupon_home',
  'root': <String, dynamic>{
    'type': 'column',
    'props': <String, dynamic>{},
    'children': <Object?>[
      <String, dynamic>{
        'type': 'primaryButton',
        'props': <String, dynamic>{
          'label': 'Show toast',
          'action': <String, dynamic>{
            'type': 'ui.toast',
            'props': <String, dynamic>{'message': 'Saved', 'durationMs': 1},
          },
        },
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'secondaryButton',
        'props': <String, dynamic>{
          'label': 'Show dialog',
          'action': <String, dynamic>{
            'type': 'ui.dialog',
            'props': <String, dynamic>{
              'title': 'Confirm',
              'message': 'Continue?',
            },
          },
        },
        'children': <Object?>[],
      },
    ],
  },
};

const Map<String, dynamic> _fullBasicScreen = <String, dynamic>{
  'schemaVersion': 1,
  'screenId': 'coupon_home',
  'root': <String, dynamic>{
    'type': 'column',
    'props': <String, dynamic>{},
    'children': <Object?>[
      <String, dynamic>{
        'type': 'heading',
        'props': <String, dynamic>{'data': 'Publisher account'},
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': 'Sign in to continue'},
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'row',
        'props': <String, dynamic>{},
        'children': <Object?>[
          <String, dynamic>{
            'type': 'sizedBox',
            'props': <String, dynamic>{'width': 8, 'height': 8},
            'children': <Object?>[],
          },
          <String, dynamic>{
            'type': 'text',
            'props': <String, dynamic>{'data': 'Inline'},
            'children': <Object?>[],
          },
        ],
      },
      <String, dynamic>{
        'type': 'image',
        'props': <String, dynamic>{
          'src': 'https://example.com/coupon.png',
          'alt': 'Coupon image',
        },
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'card',
        'props': <String, dynamic>{},
        'children': <Object?>[
          <String, dynamic>{
            'type': 'text',
            'props': <String, dynamic>{'data': 'Inside card'},
            'children': <Object?>[],
          },
        ],
      },
      <String, dynamic>{
        'type': 'primaryButton',
        'props': <String, dynamic>{
          'label': 'Sign in',
          'action': <String, dynamic>{
            'type': 'auth.showEmailAuth',
            'props': <String, dynamic>{},
          },
        },
        'children': <Object?>[],
      },
      <String, dynamic>{
        'type': 'secondaryButton',
        'props': <String, dynamic>{
          'label': 'Cancel',
          'action': <String, dynamic>{
            'type': 'auth.showEmailAuth',
            'props': <String, dynamic>{},
          },
        },
        'children': <Object?>[],
      },
    ],
  },
};

HostActionResult _ok(String actionName) {
  return HostActionResult.success(actionName: actionName);
}

DateTime _fixedNow() => DateTime.utc(2026, 6, 3, 12);

MiniProgramAuthSession _session() {
  return MiniProgramAuthSession(
    miniProgramId: 'coupon',
    user: const MiniProgramAuthUser(uid: 'user-1', email: 'user@example.com'),
    idToken: 'id-token',
    refreshToken: 'refresh-token',
    expiresAtUtc: _fixedNow().add(const Duration(hours: 1)),
  );
}

Future<Object?> _runMpAction(
  WidgetTester tester,
  Map<String, dynamic> actionJson, {
  String miniProgramId = 'coupon',
  MiniProgramCacheManager? cacheManager,
  MiniProgramCachePolicy cachePolicy = const MiniProgramCachePolicy(),
  MpStateManager? stateManager,
  MiniProgramBackendConnector? backendConnector,
  MiniProgramBackendStore? backendStore,
}) async {
  final activeBackendStore = backendStore ?? MiniProgramBackendStore();
  final ownsBackendStore = backendStore == null;
  late BuildContext actionContext;
  await tester.pumpWidget(
    MaterialApp(
      home: MiniProgramSdkScope(
        miniProgramId: miniProgramId,
        hostBridge: _NoopHostBridge(),
        capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
          CapabilityIds.auth,
        ]),
        backendConnector: backendConnector,
        cacheManager: cacheManager ?? MiniProgramCacheManager.inMemory(),
        cachePolicy: cachePolicy,
        backendStore: activeBackendStore,
        stateManager: stateManager,
        featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
        logger: const DebugPrintSdkLogger(),
        openMiniProgramScreen: (_, _) async => _ok('openMiniProgramScreen'),
        resetMiniProgramStack: (_, _) async => _ok('resetMiniProgramStack'),
        replaceMiniProgramScreen: (_, _) async =>
            _ok('replaceMiniProgramScreen'),
        popMiniProgramScreen: (_, _) async => _ok('popMiniProgramScreen'),
        popToMiniProgramRoot: (_, _) async => _ok('popToMiniProgramRoot'),
        popToMiniProgramScreen: (_, _) async => _ok('popToMiniProgramScreen'),
        child: Builder(
          builder: (context) {
            actionContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  try {
    return await tester.runAsync<Object?>(
      () => const MpActionRunner().run(actionContext, actionJson),
    );
  } finally {
    if (ownsBackendStore) {
      activeBackendStore.dispose();
    }
  }
}

MiniProgramCacheManager _fileCacheManager(Directory directory) {
  return MiniProgramCacheManager(
    store: FileMiniProgramCacheStore(directory: directory),
  );
}

class _TestClock {
  _TestClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

Widget _scopedApp({
  required MiniProgramBackendStore backendStore,
  required Map<String, dynamic> screenJson,
  MiniProgramBackendConnector? backendConnector,
  MiniProgramAuthController? authController,
  MiniProgramCacheManager? cacheManager,
  MiniProgramCachePolicy cachePolicy = const MiniProgramCachePolicy(),
  MiniProgramOpenScreenHandler? openMiniProgramScreen,
  MpStateManager? stateManager,
  MpRouter? router,
  Map<String, dynamic> routeParams = const <String, dynamic>{},
}) {
  return MaterialApp(
    home: MiniProgramSdkScope(
      miniProgramId: 'coupon',
      hostBridge: _NoopHostBridge(),
      capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
        CapabilityIds.auth,
      ]),
      backendConnector: backendConnector,
      authController: authController,
      cacheManager: cacheManager ?? MiniProgramCacheManager.inMemory(),
      cachePolicy: cachePolicy,
      backendStore: backendStore,
      stateManager: stateManager,
      router: router,
      routeParams: routeParams,
      featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
      logger: const DebugPrintSdkLogger(),
      openMiniProgramScreen:
          openMiniProgramScreen ?? (_, _) async => _ok('openMiniProgramScreen'),
      resetMiniProgramStack: (_, _) async => _ok('resetMiniProgramStack'),
      replaceMiniProgramScreen: (_, _) async => _ok('replaceMiniProgramScreen'),
      popMiniProgramScreen: (_, _) async => _ok('popMiniProgramScreen'),
      popToMiniProgramRoot: (_, _) async => _ok('popToMiniProgramRoot'),
      popToMiniProgramScreen: (_, _) async => _ok('popToMiniProgramScreen'),
      child: Builder(
        builder: (context) {
          return const MpScreenRenderer().render(
            MiniProgramRenderRequest(
              context: context,
              manifest: _mpManifest,
              screenId: 'coupon_home',
              screenJson: screenJson,
              logger: DebugPrintSdkLogger(),
            ),
          );
        },
      ),
    ),
  );
}

class _AuthConnector implements MiniProgramBackendConnector {
  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    return MiniProgramBackendResult.success(
      endpoint: request.endpoint,
      method: request.method,
      data: const <String, dynamic>{
        'authenticated': true,
        'user': <String, dynamic>{'uid': 'user-1', 'email': 'user@example.com'},
        'idToken': 'id-token',
        'refreshToken': 'refresh-token',
        'expiresIn': 3600,
      },
    );
  }
}

class _RecordingBackendConnector implements MiniProgramBackendConnector {
  _RecordingBackendConnector({
    required List<MiniProgramBackendResult> responses,
  }) : _responses = Queue<MiniProgramBackendResult>.of(responses);

  final Queue<MiniProgramBackendResult> _responses;
  final List<MiniProgramBackendRequest> calls = <MiniProgramBackendRequest>[];

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    calls.add(request);
    return _responses.removeFirst();
  }
}

class _FutureBackendConnector implements MiniProgramBackendConnector {
  _FutureBackendConnector({
    required List<FutureOr<MiniProgramBackendResult>> responses,
  }) : _responses = Queue<FutureOr<MiniProgramBackendResult>>.of(responses);

  final Queue<FutureOr<MiniProgramBackendResult>> _responses;
  final List<MiniProgramBackendRequest> calls = <MiniProgramBackendRequest>[];

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    calls.add(request);
    return _responses.removeFirst();
  }
}

class _NoopHostBridge implements HostBridge {
  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return _ok(ActionNames.callSecureApi);
  }

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    return _ok(ActionNames.openNativeScreen);
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    return _ok(ActionNames.trackEvent);
  }
}
