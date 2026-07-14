import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('MiniProgramBackendStore ignores stale results after clear', () async {
    final completer = Completer<MiniProgramBackendResult>();
    final store = MiniProgramBackendStore();
    final connector = _CompleterBackendConnector(completer);

    final future = store.runQuery(
      connector: connector,
      miniProgramId: 'coupon',
      query: const MiniProgramBackendQuery(
        requestId: 'home',
        endpoint: 'home/bootstrap',
      ),
    );

    expect(store.snapshot('home').isLoading, isTrue);
    store.clear();

    completer.complete(
      MiniProgramBackendResult.success(
        requestId: 'home',
        endpoint: 'home/bootstrap',
        data: const <String, dynamic>{'title': 'Old response'},
      ),
    );

    await future;
    expect(store.snapshot('home').isIdle, isTrue);
  });

  test('paged first page stores items and pagination bindings', () async {
    final store = MiniProgramBackendStore();
    final connector = _RecordingBackendConnector(
      responses: <MiniProgramBackendResult>[
        MiniProgramBackendResult.success(
          data: const <String, dynamic>{
            'items': [
              <String, dynamic>{'id': 'coupon-1'},
              <String, dynamic>{'id': 'coupon-2'},
            ],
            'nextCursor': 'coupon-2',
            'hasMore': true,
          },
        ),
      ],
    );

    final snapshot = await store.runPagedQuery(
      connector: connector,
      miniProgramId: 'coupon',
      query: const MiniProgramPagedBackendQuery(
        requestId: 'coupons',
        endpoint: 'coupons/list',
      ),
    );

    expect(snapshot.items, hasLength(2));
    expect(snapshot.nextCursor, 'coupon-2');
    expect(snapshot.hasMore, isTrue);
    expect(snapshot.pageCount, 1);
    expect(snapshot.toBindingData()['itemCount'], 2);
    expect(connector.calls.single.endpoint, 'coupons/list?limit=20');
  });

  test('paged load-more appends items instead of replacing', () async {
    final store = MiniProgramBackendStore();
    final connector = _RecordingBackendConnector(
      responses: <MiniProgramBackendResult>[
        MiniProgramBackendResult.success(
          data: const <String, dynamic>{
            'items': [
              <String, dynamic>{'id': 'coupon-1'},
            ],
            'nextCursor': 'coupon-1',
            'hasMore': true,
          },
        ),
        MiniProgramBackendResult.success(
          data: const <String, dynamic>{
            'items': [
              <String, dynamic>{'id': 'coupon-2'},
            ],
            'nextCursor': null,
            'hasMore': false,
          },
        ),
      ],
    );

    const query = MiniProgramPagedBackendQuery(
      requestId: 'coupons',
      endpoint: 'coupons/list',
      limit: 1,
    );
    await store.runPagedQuery(
      connector: connector,
      miniProgramId: 'coupon',
      query: query,
    );
    final snapshot = await store.loadMoreByRequestId(
      connector: connector,
      miniProgramId: 'coupon',
      requestId: 'coupons',
    );

    expect(snapshot.items, hasLength(2));
    expect(snapshot.pageCount, 2);
    expect(snapshot.hasMore, isFalse);
    expect(connector.calls[1].endpoint, 'coupons/list?limit=1&cursor=coupon-1');
  });

  test('paged load-more ignores duplicate calls while in flight', () async {
    final completer = Completer<MiniProgramBackendResult>();
    final store = MiniProgramBackendStore();
    final connector = _DeferredBackendConnector(completer);
    await store.runPagedQuery(
      connector: _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            data: const <String, dynamic>{
              'items': [
                <String, dynamic>{'id': 'coupon-1'},
              ],
              'nextCursor': 'coupon-1',
              'hasMore': true,
            },
          ),
        ],
      ),
      miniProgramId: 'coupon',
      query: const MiniProgramPagedBackendQuery(
        requestId: 'coupons',
        endpoint: 'coupons/list',
      ),
    );

    final first = store.loadMoreByRequestId(
      connector: connector,
      miniProgramId: 'coupon',
      requestId: 'coupons',
    );
    final second = store.loadMoreByRequestId(
      connector: connector,
      miniProgramId: 'coupon',
      requestId: 'coupons',
    );

    expect(connector.calls, hasLength(1));
    completer.complete(
      MiniProgramBackendResult.success(
        data: const <String, dynamic>{
          'items': [
            <String, dynamic>{'id': 'coupon-2'},
          ],
          'nextCursor': null,
          'hasMore': false,
        },
      ),
    );

    expect(await first, same(await second));
    expect(store.pagedSnapshot('coupons').items, hasLength(2));
  });

  test(
    'paged failed load-more keeps previous items and exposes error',
    () async {
      final store = MiniProgramBackendStore();
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            data: const <String, dynamic>{
              'items': [
                <String, dynamic>{'id': 'coupon-1'},
              ],
              'nextCursor': 'coupon-1',
              'hasMore': true,
            },
          ),
          MiniProgramBackendResult.failed(
            message: 'Backend failed',
            errorCode: 'backend_failed',
          ),
        ],
      );

      const query = MiniProgramPagedBackendQuery(
        requestId: 'coupons',
        endpoint: 'coupons/list',
      );
      await store.runPagedQuery(
        connector: connector,
        miniProgramId: 'coupon',
        query: query,
      );
      final snapshot = await store.loadMore(
        connector: connector,
        miniProgramId: 'coupon',
        query: query,
      );

      expect(snapshot.isFailure, isTrue);
      expect(snapshot.items, hasLength(1));
      expect(snapshot.message, 'Backend failed');
      expect(snapshot.errorCode, 'backend_failed');
    },
  );

  test('paged query supports custom paths and query parameter names', () async {
    final store = MiniProgramBackendStore();
    final connector = _RecordingBackendConnector(
      responses: <MiniProgramBackendResult>[
        MiniProgramBackendResult.success(
          data: const <String, dynamic>{
            'payload': <String, dynamic>{
              'rows': [
                <String, dynamic>{'id': 'row-1'},
              ],
              'cursor': 'row-1',
              'more': true,
            },
          },
        ),
      ],
    );

    final snapshot = await store.runPagedQuery(
      connector: connector,
      miniProgramId: 'coupon',
      query: const MiniProgramPagedBackendQuery(
        requestId: 'rows',
        endpoint: 'rows/list?sort=created',
        limit: 10,
        limitParam: 'pageSize',
        cursorParam: 'after',
        itemsPath: 'payload.rows',
        nextCursorPath: 'payload.cursor',
        hasMorePath: 'payload.more',
      ),
    );

    expect(snapshot.items, hasLength(1));
    expect(snapshot.nextCursor, 'row-1');
    expect(snapshot.hasMore, isTrue);
    expect(
      connector.calls.single.endpoint,
      'rows/list?sort=created&pageSize=10',
    );
  });

  test(
    'paged query uses request interceptor for initial and load-more',
    () async {
      final store = MiniProgramBackendStore();
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            data: const <String, dynamic>{
              'items': [
                <String, dynamic>{'id': 'coupon-1'},
              ],
              'nextCursor': 'coupon-1',
              'hasMore': true,
            },
          ),
          MiniProgramBackendResult.success(
            data: const <String, dynamic>{
              'items': [
                <String, dynamic>{'id': 'coupon-2'},
              ],
              'hasMore': false,
            },
          ),
        ],
      );

      Future<MiniProgramBackendRequest> addAuth(
        MiniProgramBackendRequest request,
      ) async {
        return request.copyWith(
          headers: <String, String>{
            ...request.headers,
            'authorization': 'Bearer test-token',
          },
        );
      }

      const query = MiniProgramPagedBackendQuery(
        requestId: 'coupons',
        endpoint: 'coupons/list',
      );
      await store.runPagedQuery(
        connector: connector,
        miniProgramId: 'coupon',
        query: query,
        requestInterceptor: addAuth,
      );
      await store.loadMore(
        connector: connector,
        miniProgramId: 'coupon',
        query: query,
        requestInterceptor: addAuth,
      );

      expect(connector.calls, hasLength(2));
      expect(connector.calls[0].headers['authorization'], 'Bearer test-token');
      expect(connector.calls[1].headers['authorization'], 'Bearer test-token');
    },
  );

  test('forwards force refresh to the backend connector', () async {
    final store = MiniProgramBackendStore();
    final connector = _RecordingBackendConnector(
      responses: <MiniProgramBackendResult>[MiniProgramBackendResult.success()],
    );

    await store.runQuery(
      connector: connector,
      miniProgramId: 'weather',
      query: const MiniProgramBackendQuery(
        requestId: 'weather-refresh',
        endpoint: 'forecast',
        forceRefresh: true,
      ),
    );

    expect(connector.calls.single.forceRefresh, isTrue);
  });
}

class _CompleterBackendConnector implements MiniProgramBackendConnector {
  const _CompleterBackendConnector(this.completer);

  final Completer<MiniProgramBackendResult> completer;

  @override
  Future<MiniProgramBackendResult> call(MiniProgramBackendRequest request) {
    return completer.future;
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

class _DeferredBackendConnector implements MiniProgramBackendConnector {
  _DeferredBackendConnector(this.completer);

  final Completer<MiniProgramBackendResult> completer;
  final List<MiniProgramBackendRequest> calls = <MiniProgramBackendRequest>[];

  @override
  Future<MiniProgramBackendResult> call(MiniProgramBackendRequest request) {
    calls.add(request);
    return completer.future;
  }
}
