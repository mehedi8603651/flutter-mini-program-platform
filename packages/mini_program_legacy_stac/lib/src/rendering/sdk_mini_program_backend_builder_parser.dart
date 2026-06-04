import 'package:flutter/widgets.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:stac/stac.dart';


class SdkMiniProgramBackendBuilderModel {
  const SdkMiniProgramBackendBuilderModel({
    required this.requestId,
    required this.endpoint,
    this.method = 'GET',
    this.body = const <String, dynamic>{},
    this.cacheTtlSeconds,
    this.forceRefresh = false,
    this.loading,
    this.error,
    this.child,
    this.empty,
    this.itemTemplate,
    this.itemsPath,
  });

  static const String typeName = 'miniProgramBackendBuilder';

  final String requestId;
  final String endpoint;
  final String method;
  final Map<String, dynamic> body;
  final int? cacheTtlSeconds;
  final bool forceRefresh;
  final Map<String, dynamic>? loading;
  final Map<String, dynamic>? error;
  final Map<String, dynamic>? child;
  final Map<String, dynamic>? empty;
  final Map<String, dynamic>? itemTemplate;
  final String? itemsPath;

  factory SdkMiniProgramBackendBuilderModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final requestId = json['requestId'];
    if (requestId is! String || requestId.trim().isEmpty) {
      throw const FormatException(
        'miniProgramBackendBuilder requires a non-empty "requestId" string.',
      );
    }

    final endpoint = json['endpoint'];
    if (endpoint is! String || endpoint.trim().isEmpty) {
      throw const FormatException(
        'miniProgramBackendBuilder requires a non-empty "endpoint" string.',
      );
    }

    final method = json['method'];
    if (method != null && method is! String) {
      throw const FormatException('"method" must be a string when provided.');
    }

    final body = json['body'];
    if (body != null && body is! Map) {
      throw const FormatException('"body" must be a JSON object.');
    }

    final cacheTtlSeconds = json['cacheTtlSeconds'];
    if (cacheTtlSeconds != null && cacheTtlSeconds is! int) {
      throw const FormatException(
        '"cacheTtlSeconds" must be an integer when provided.',
      );
    }

    final forceRefresh = json['forceRefresh'];
    if (forceRefresh != null && forceRefresh is! bool) {
      throw const FormatException(
        '"forceRefresh" must be a boolean when provided.',
      );
    }

    return SdkMiniProgramBackendBuilderModel(
      requestId: requestId,
      endpoint: endpoint,
      method: method as String? ?? 'GET',
      body: body == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(body as Map),
      cacheTtlSeconds: cacheTtlSeconds as int?,
      forceRefresh: forceRefresh as bool? ?? false,
      loading: _optionalWidgetJson(json['loading'], 'loading'),
      error: _optionalWidgetJson(json['error'], 'error'),
      child: _optionalWidgetJson(json['child'], 'child'),
      empty: _optionalWidgetJson(json['empty'], 'empty'),
      itemTemplate: _optionalWidgetJson(json['itemTemplate'], 'itemTemplate'),
      itemsPath: json['itemsPath'] as String?,
    );
  }

  MiniProgramBackendQuery toQuery() {
    final ttl = cacheTtlSeconds;
    return MiniProgramBackendQuery(
      requestId: requestId,
      endpoint: endpoint,
      method: method,
      body: body,
      cacheTtl: ttl == null ? null : Duration(seconds: ttl),
      forceRefresh: forceRefresh,
    );
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

class SdkMiniProgramBackendBuilderParser
    extends StacParser<SdkMiniProgramBackendBuilderModel> {
  const SdkMiniProgramBackendBuilderParser();

  @override
  String get type => SdkMiniProgramBackendBuilderModel.typeName;

  @override
  SdkMiniProgramBackendBuilderModel getModel(Map<String, dynamic> json) =>
      SdkMiniProgramBackendBuilderModel.fromJson(json);

  @override
  Widget parse(BuildContext context, SdkMiniProgramBackendBuilderModel model) {
    return _MiniProgramBackendBuilder(model: model);
  }
}

class _MiniProgramBackendBuilder extends StatefulWidget {
  const _MiniProgramBackendBuilder({required this.model});

  final SdkMiniProgramBackendBuilderModel model;

  @override
  State<_MiniProgramBackendBuilder> createState() =>
      _MiniProgramBackendBuilderState();
}

class _MiniProgramBackendBuilderState
    extends State<_MiniProgramBackendBuilder> {
  static const MiniProgramBackendBindingResolver _resolver =
      MiniProgramBackendBindingResolver();

  String? _startedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MiniProgramBackendBuilder oldWidget) {
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

    final snapshot = scope.backendStore.snapshot(model.requestId);
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
      activeScope.backendStore.runQuery(
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
        final snapshot = scope.backendStore.snapshot(widget.model.requestId);
        return _renderSnapshot(scope, snapshot);
      },
    );
  }

  Widget _renderSnapshot(
    MiniProgramSdkScope scope,
    MiniProgramBackendSnapshot snapshot,
  ) {
    final model = widget.model;
    if ((snapshot.isIdle || snapshot.isLoading) && !snapshot.hasData) {
      return _renderTemplate(scope, model.loading) ?? const SizedBox.shrink();
    }

    if (snapshot.isFailure) {
      return _renderTemplate(scope, model.error) ??
          _renderTemplate(scope, model.child) ??
          const SizedBox.shrink();
    }

    if (model.itemTemplate != null) {
      return _renderItems(scope, snapshot);
    }

    return _renderTemplate(scope, model.child) ?? const SizedBox.shrink();
  }

  Widget _renderItems(
    MiniProgramSdkScope scope,
    MiniProgramBackendSnapshot snapshot,
  ) {
    final model = widget.model;
    final itemsPath = model.itemsPath?.trim();
    final rawItems = itemsPath == null || itemsPath.isEmpty
        ? snapshot.data['items']
        : _resolver.readPath(snapshot.toBindingData(), itemsPath);
    if (rawItems is! List || rawItems.isEmpty) {
      return _renderTemplate(scope, model.empty) ?? const SizedBox.shrink();
    }

    final widgets = <Widget>[];
    final authBindings = _authBindings(scope);
    for (final rawItem in rawItems) {
      final item = rawItem is Map
          ? Map<String, dynamic>.from(rawItem)
          : <String, dynamic>{'value': rawItem};
      final resolved = _resolver.resolveTemplate(
        model.itemTemplate,
        store: scope.backendStore,
        item: item,
        bindings: authBindings,
      );
      final rendered = _renderResolved(resolved);
      if (rendered != null) {
        widgets.add(rendered);
      }
    }

    if (widgets.isEmpty) {
      return _renderTemplate(scope, model.empty) ?? const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
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

  String _queryKey(SdkMiniProgramBackendBuilderModel model) {
    return '${model.requestId}|${model.endpoint}|${model.method}|'
        '${model.cacheTtlSeconds}|${model.forceRefresh}|${model.body}';
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
