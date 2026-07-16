part of '../../../mp_screen_renderer.dart';

class _MpLazyChunkPage {
  const _MpLazyChunkPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.pageCount,
  });

  final List<Object?> items;
  final Object? nextCursor;
  final bool hasMore;
  final int pageCount;

  _MpLazyChunkPage copyWith({List<Object?>? items, int? pageCount}) {
    return _MpLazyChunkPage(
      items: items ?? this.items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      pageCount: pageCount ?? this.pageCount,
    );
  }
}

class _MpLazyChunkActionOutcome {
  const _MpLazyChunkActionOutcome.success(this.page)
    : success = true,
      data = null;

  const _MpLazyChunkActionOutcome.failure([this.data])
    : success = false,
      page = const _MpLazyChunkPage(
        items: <Object?>[],
        nextCursor: null,
        hasMore: false,
        pageCount: 0,
      );

  final bool success;
  final _MpLazyChunkPage page;
  final Object? data;
}

abstract final class _MpLazyChunkRegistry {
  static final Map<String, _MpLazyChunkState> _entries =
      <String, _MpLazyChunkState>{};

  static void register(String key, _MpLazyChunkState state) {
    _entries[key] = state;
  }

  static void unregister(String key, _MpLazyChunkState state) {
    if (identical(_entries[key], state)) {
      _entries.remove(key);
    }
  }

  static Future<HostActionResult> loadMore({
    required MiniProgramSdkScope scope,
    required String? screenId,
    required String id,
  }) {
    final key = _lazyChunkRegistryKey(scope.miniProgramId, screenId, id);
    final state = _entries[key];
    if (state == null) {
      return Future<HostActionResult>.value(
        HostActionResult.failed(
          actionName: 'lazy.chunk.loadMore',
          message: 'No active Mp lazy chunk is registered for "$id".',
          errorCode: 'lazy_chunk_not_registered',
        ),
      );
    }
    return state.loadMoreFromAction();
  }
}

final Set<String> _mpLazyChunkOnceKeys = <String>{};

class _MpLazyActionOutcome {
  const _MpLazyActionOutcome.success({this.data, this.hasData = true})
    : success = true;

  const _MpLazyActionOutcome.failure([this.data])
    : success = false,
      hasData = false;

  final bool success;
  final Object? data;
  final bool hasData;
}

final Set<String> _mpLazyOnceKeys = <String>{};
