import 'package:flutter/widgets.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:stac/stac.dart';


class SdkMiniProgramPagedBackendBuilderModel {
  const SdkMiniProgramPagedBackendBuilderModel({
    required this.requestId,
    required this.endpoint,
    required this.itemTemplate,
    this.limit = 20,
    this.initialCursor,
    this.cursorParam = 'cursor',
    this.limitParam = 'limit',
    this.itemsPath = 'items',
    this.nextCursorPath = 'nextCursor',
    this.hasMorePath = 'hasMore',
    this.cacheTtlSeconds,
    this.forceRefresh = false,
    this.loading,
    this.loadingMore,
    this.error,
    this.empty,
    this.end,
    this.loadMore,
  });

  static const String typeName = 'miniProgramPagedBackendBuilder';

  final String requestId;
  final String endpoint;
  final int limit;
  final String? initialCursor;
  final String cursorParam;
  final String limitParam;
  final String itemsPath;
  final String nextCursorPath;
  final String hasMorePath;
  final int? cacheTtlSeconds;
  final bool forceRefresh;
  final Map<String, dynamic>? loading;
  final Map<String, dynamic>? loadingMore;
  final Map<String, dynamic>? error;
  final Map<String, dynamic>? empty;
  final Map<String, dynamic>? end;
  final Map<String, dynamic>? loadMore;
  final Map<String, dynamic> itemTemplate;

  factory SdkMiniProgramPagedBackendBuilderModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final forceRefresh = json['forceRefresh'];
    if (forceRefresh != null && forceRefresh is! bool) {
      throw const FormatException(
        '"forceRefresh" must be a boolean when provided.',
      );
    }

    return SdkMiniProgramPagedBackendBuilderModel(
      requestId: _requiredString(json, 'requestId'),
      endpoint: _requiredString(json, 'endpoint'),
      itemTemplate: _requiredWidgetJson(json['itemTemplate'], 'itemTemplate'),
      limit: _optionalPositiveInt(json, 'limit') ?? 20,
      initialCursor: _optionalString(json, 'initialCursor'),
      cursorParam: _optionalString(json, 'cursorParam') ?? 'cursor',
      limitParam: _optionalString(json, 'limitParam') ?? 'limit',
      itemsPath: _optionalString(json, 'itemsPath') ?? 'items',
      nextCursorPath: _optionalString(json, 'nextCursorPath') ?? 'nextCursor',
      hasMorePath: _optionalString(json, 'hasMorePath') ?? 'hasMore',
      cacheTtlSeconds: _optionalPositiveInt(json, 'cacheTtlSeconds'),
      forceRefresh: forceRefresh as bool? ?? false,
      loading: _optionalWidgetJson(json['loading'], 'loading'),
      loadingMore: _optionalWidgetJson(json['loadingMore'], 'loadingMore'),
      error: _optionalWidgetJson(json['error'], 'error'),
      empty: _optionalWidgetJson(json['empty'], 'empty'),
      end: _optionalWidgetJson(json['end'], 'end'),
      loadMore: _optionalWidgetJson(json['loadMore'], 'loadMore'),
    );
  }

  MiniProgramPagedBackendQuery toQuery() {
    final ttl = cacheTtlSeconds;
    return MiniProgramPagedBackendQuery(
      requestId: requestId,
      endpoint: endpoint,
      limit: limit,
      initialCursor: initialCursor,
      cursorParam: cursorParam,
      limitParam: limitParam,
      itemsPath: itemsPath,
      nextCursorPath: nextCursorPath,
      hasMorePath: hasMorePath,
      cacheTtl: ttl == null ? null : Duration(seconds: ttl),
      forceRefresh: forceRefresh,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String fieldName) {
    final value = json[fieldName];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'miniProgramPagedBackendBuilder requires a non-empty "$fieldName" string.',
      );
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> json, String fieldName) {
    final value = json[fieldName];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('"$fieldName" must be a string when provided.');
    }
    return value;
  }

  static int? _optionalPositiveInt(
    Map<String, dynamic> json,
    String fieldName,
  ) {
    final value = json[fieldName];
    if (value == null) {
      return null;
    }
    if (value is! int || value <= 0) {
      throw FormatException('"$fieldName" must be a positive integer.');
    }
    return value;
  }

  static Map<String, dynamic> _requiredWidgetJson(
    Object? value,
    String fieldName,
  ) {
    if (value is! Map) {
      throw FormatException(
        'miniProgramPagedBackendBuilder requires "$fieldName" as a widget JSON object.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  static Map<String, dynamic>? _optionalWidgetJson(
    Object? value,
    String fieldName,
  ) {
    if (value == null) {
      return null;
    }
    if (value is! Map) {
      throw FormatException('"$fieldName" must be a widget JSON object.');
    }
    return Map<String, dynamic>.from(value);
  }
}

class SdkMiniProgramPagedBackendBuilderParser
    extends StacParser<SdkMiniProgramPagedBackendBuilderModel> {
  const SdkMiniProgramPagedBackendBuilderParser();

  @override
  String get type => SdkMiniProgramPagedBackendBuilderModel.typeName;

  @override
  SdkMiniProgramPagedBackendBuilderModel getModel(Map<String, dynamic> json) =>
      SdkMiniProgramPagedBackendBuilderModel.fromJson(json);

  @override
  Widget parse(
    BuildContext context,
    SdkMiniProgramPagedBackendBuilderModel model,
  ) {
    return _MiniProgramPagedBackendBuilder(model: model);
  }
}

class _MiniProgramPagedBackendBuilder extends StatefulWidget {
  const _MiniProgramPagedBackendBuilder({required this.model});

  final SdkMiniProgramPagedBackendBuilderModel model;

  @override
  State<_MiniProgramPagedBackendBuilder> createState() =>
      _MiniProgramPagedBackendBuilderState();
}

class _MiniProgramPagedBackendBuilderState
    extends State<_MiniProgramPagedBackendBuilder> {
  static const MiniProgramBackendBindingResolver _resolver =
      MiniProgramBackendBindingResolver();

  String? _startedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MiniProgramPagedBackendBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_queryKey(widget.model) != _queryKey(oldWidget.model)) {
      _startedKey = null;
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }

    final model = widget.model;
    final key = _queryKey(model);
    if (_startedKey == key) {
      return;
    }

    final snapshot = scope.backendStore.pagedSnapshot(model.requestId);
    if (!model.forceRefresh && !snapshot.isIdle) {
      _startedKey = key;
      return;
    }

    _startedKey = key;
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final activeScope = MiniProgramSdkScope.maybeOf(context);
      if (activeScope == null) {
        return;
      }
      activeScope.backendStore.runPagedQuery(
        connector: activeScope.backendConnector,
        miniProgramId: activeScope.miniProgramId,
        query: model.toQuery(),
        requestInterceptor: activeScope.authController == null
            ? null
            : (request) => activeScope.authController!.authorizeRequest(
                request: request,
                connector: activeScope.backendConnector,
              ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: scope.authController == null
          ? scope.backendStore
          : Listenable.merge(<Listenable>[
              scope.backendStore,
              scope.authController!,
            ]),
      builder: (context, _) {
        final snapshot = scope.backendStore.pagedSnapshot(
          widget.model.requestId,
        );
        return _renderSnapshot(scope, snapshot);
      },
    );
  }

  Widget _renderSnapshot(
    MiniProgramSdkScope scope,
    MiniProgramPagedBackendSnapshot snapshot,
  ) {
    final model = widget.model;
    if ((snapshot.isIdle || snapshot.isLoading) && !snapshot.hasItems) {
      return _renderTemplate(scope, model.loading) ?? const SizedBox.shrink();
    }

    if (snapshot.isFailure && !snapshot.hasItems) {
      return _renderTemplate(scope, model.error) ?? const SizedBox.shrink();
    }

    if (!snapshot.hasItems) {
      return _renderTemplate(scope, model.empty) ?? const SizedBox.shrink();
    }

    final children = <Widget>[];
    children.addAll(_renderItems(scope, snapshot));

    if (snapshot.isFailure) {
      final error = _renderTemplate(scope, model.error);
      if (error != null) {
        children.add(error);
      }
    } else if (snapshot.loadingMore) {
      final loadingMore = _renderTemplate(scope, model.loadingMore);
      if (loadingMore != null) {
        children.add(loadingMore);
      }
    } else if (snapshot.hasMore) {
      final loadMore = _renderTemplate(scope, model.loadMore);
      if (loadMore != null) {
        children.add(loadMore);
      }
    } else {
      final end = _renderTemplate(scope, model.end);
      if (end != null) {
        children.add(end);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<Widget> _renderItems(
    MiniProgramSdkScope scope,
    MiniProgramPagedBackendSnapshot snapshot,
  ) {
    final widgets = <Widget>[];
    final authBindings = _authBindings(scope);
    for (final rawItem in snapshot.items) {
      final item = rawItem is Map
          ? Map<String, dynamic>.from(rawItem)
          : <String, dynamic>{'value': rawItem};
      final resolved = _resolver.resolveTemplate(
        widget.model.itemTemplate,
        store: scope.backendStore,
        item: item,
        bindings: authBindings,
      );
      final rendered = _renderResolved(resolved);
      if (rendered != null) {
        widgets.add(rendered);
      }
    }
    return widgets;
  }

  Widget? _renderTemplate(
    MiniProgramSdkScope scope,
    Map<String, dynamic>? template,
  ) {
    if (template == null) {
      return null;
    }
    return _renderResolved(
      _resolver.resolveTemplate(
        template,
        store: scope.backendStore,
        bindings: _authBindings(scope),
      ),
    );
  }

  Widget? _renderResolved(Object? resolved) {
    if (resolved is! Map) {
      return null;
    }
    return Stac.fromJson(Map<String, dynamic>.from(resolved), context);
  }

  String _queryKey(SdkMiniProgramPagedBackendBuilderModel model) {
    return '${model.requestId}|${model.endpoint}|${model.limit}|'
        '${model.initialCursor}|${model.cursorParam}|${model.limitParam}|'
        '${model.itemsPath}|${model.nextCursorPath}|${model.hasMorePath}|'
        '${model.cacheTtlSeconds}|${model.forceRefresh}';
  }

  Map<String, dynamic> _authBindings(MiniProgramSdkScope scope) {
    final authController = scope.authController;
    if (authController == null) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{
      'auth': authController.snapshot(scope.miniProgramId).toBindingData(),
    };
  }
}
