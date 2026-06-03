import 'mp_action.dart';
import 'mp_node.dart';

/// Author-friendly namespace for Mp widget and action builders.
abstract final class Mp {
  /// Email authentication actions.
  static const auth = MpAuthActions();

  /// Publisher backend actions.
  static const backend = MpBackendActions();

  /// Mini-program screen navigation actions.
  static const navigation = MpNavigationActions();

  /// Creates a vertical layout.
  static MpNode column({required List<MpNode> children}) =>
      MpNode('column', children: children);

  /// Creates a horizontal layout.
  static MpNode row({required List<MpNode> children}) =>
      MpNode('row', children: children);

  /// Creates body text.
  static MpNode text(String data) =>
      MpNode('text', props: <String, Object?>{'data': data});

  /// Creates heading text.
  static MpNode heading(String data) =>
      MpNode('heading', props: <String, Object?>{'data': data});

  /// Creates fixed empty space.
  static MpNode sizedBox({num? width, num? height}) {
    if (width == null && height == null) {
      throw ArgumentError('Provide width, height, or both for Mp.sizedBox.');
    }
    return MpNode(
      'sizedBox',
      props: <String, Object?>{
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      },
    );
  }

  /// Creates an image node.
  static MpNode image({required String src, String? alt}) => MpNode(
    'image',
    props: <String, Object?>{'src': src, if (alt != null) 'alt': alt},
  );

  /// Creates a simple card container.
  static MpNode card({required MpNode child}) =>
      MpNode('card', children: <MpNode>[child]);

  /// Creates the primary button style.
  static MpNode primaryButton({
    required String label,
    required MpAction action,
  }) => MpNode(
    'primaryButton',
    props: <String, Object?>{'label': label, 'action': action},
  );

  /// Creates the secondary button style.
  static MpNode secondaryButton({
    required String label,
    required MpAction action,
  }) => MpNode(
    'secondaryButton',
    props: <String, Object?>{'label': label, 'action': action},
  );

  /// Creates an auth state builder.
  static MpNode authBuilder({
    MpNode? loading,
    MpNode? signedOut,
    MpNode? signedIn,
    MpNode? error,
  }) => MpNode(
    'authBuilder',
    props: <String, Object?>{
      if (loading != null) 'loading': loading,
      if (signedOut != null) 'signedOut': signedOut,
      if (signedIn != null) 'signedIn': signedIn,
      if (error != null) 'error': error,
    },
  );

  /// Creates a publisher backend data builder.
  static MpNode backendBuilder({
    required String requestId,
    required String endpoint,
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    int? cacheTtlSeconds,
    bool forceRefresh = false,
    MpNode? loading,
    MpNode? error,
    MpNode? empty,
    MpNode? child,
    MpNode? itemTemplate,
    String? itemsPath,
  }) => MpNode(
    'backendBuilder',
    props: <String, Object?>{
      'requestId': _requiredString(requestId, 'requestId'),
      'endpoint': _requiredString(endpoint, 'endpoint'),
      'method': _requiredString(method, 'method'),
      if (body.isNotEmpty) 'body': body,
      if (cacheTtlSeconds != null)
        'cacheTtlSeconds': _positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
      if (forceRefresh) 'forceRefresh': true,
      if (loading != null) 'loading': loading,
      if (error != null) 'error': error,
      if (empty != null) 'empty': empty,
      if (child != null) 'child': child,
      if (itemTemplate != null) 'itemTemplate': itemTemplate,
      if (itemsPath != null)
        'itemsPath': _requiredString(itemsPath, 'itemsPath'),
    },
  );

  /// Creates a paged publisher backend data builder.
  static MpNode pagedBackendBuilder({
    required String requestId,
    required String endpoint,
    required MpNode itemTemplate,
    int limit = 20,
    String? initialCursor,
    String cursorParam = 'cursor',
    String limitParam = 'limit',
    String itemsPath = 'items',
    String nextCursorPath = 'nextCursor',
    String hasMorePath = 'hasMore',
    int? cacheTtlSeconds,
    bool forceRefresh = false,
    MpNode? loading,
    MpNode? loadingMore,
    MpNode? error,
    MpNode? empty,
    MpNode? end,
    MpNode? loadMore,
  }) => MpNode(
    'pagedBackendBuilder',
    props: <String, Object?>{
      'requestId': _requiredString(requestId, 'requestId'),
      'endpoint': _requiredString(endpoint, 'endpoint'),
      'itemTemplate': itemTemplate,
      'limit': _positiveInt(limit, 'limit'),
      if (initialCursor != null)
        'initialCursor': _requiredString(initialCursor, 'initialCursor'),
      'cursorParam': _requiredString(cursorParam, 'cursorParam'),
      'limitParam': _requiredString(limitParam, 'limitParam'),
      'itemsPath': _requiredString(itemsPath, 'itemsPath'),
      'nextCursorPath': _requiredString(nextCursorPath, 'nextCursorPath'),
      'hasMorePath': _requiredString(hasMorePath, 'hasMorePath'),
      if (cacheTtlSeconds != null)
        'cacheTtlSeconds': _positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
      if (forceRefresh) 'forceRefresh': true,
      if (loading != null) 'loading': loading,
      if (loadingMore != null) 'loadingMore': loadingMore,
      if (error != null) 'error': error,
      if (empty != null) 'empty': empty,
      if (end != null) 'end': end,
      if (loadMore != null) 'loadMore': loadMore,
    },
  );
}

/// Email authentication action builders.
final class MpAuthActions {
  /// Creates email authentication action helpers.
  const MpAuthActions();

  /// Shows the SDK-owned email/password auth sheet.
  MpAction showEmailAuth({String? mode}) => MpAction(
    'auth.showEmailAuth',
    props: <String, Object?>{
      if (mode != null) 'mode': _requiredString(mode, 'mode'),
    },
  );

  /// Signs out the current mini-program auth session.
  MpAction signOut() => MpAction('auth.signOut');

  /// Restores the cached mini-program auth session.
  MpAction restore() => MpAction('auth.restore');

  /// Refreshes the current mini-program auth session.
  MpAction refresh() => MpAction('auth.refresh');
}

/// Publisher backend action builders.
final class MpBackendActions {
  /// Creates publisher backend action helpers.
  const MpBackendActions();

  /// Calls a publisher backend endpoint without storing state.
  MpAction call({
    required String endpoint,
    String? requestId,
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    int? cacheTtlSeconds,
  }) => MpAction(
    'backend.call',
    props: <String, Object?>{
      'endpoint': _requiredString(endpoint, 'endpoint'),
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
      'method': _requiredString(method, 'method'),
      if (body.isNotEmpty) 'body': body,
      if (cacheTtlSeconds != null)
        'cacheTtlSeconds': _positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
    },
  );

  /// Queries a publisher backend endpoint into SDK backend state.
  MpAction query({
    required String requestId,
    required String endpoint,
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    int? cacheTtlSeconds,
    bool forceRefresh = false,
  }) => MpAction(
    'backend.query',
    props: <String, Object?>{
      'requestId': _requiredString(requestId, 'requestId'),
      'endpoint': _requiredString(endpoint, 'endpoint'),
      'method': _requiredString(method, 'method'),
      if (body.isNotEmpty) 'body': body,
      if (cacheTtlSeconds != null)
        'cacheTtlSeconds': _positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
      if (forceRefresh) 'forceRefresh': true,
    },
  );

  /// Loads the next page for a paged publisher backend query.
  MpAction loadMore({
    required String requestId,
    String? endpoint,
    int limit = 20,
    String? initialCursor,
    String cursorParam = 'cursor',
    String limitParam = 'limit',
    String itemsPath = 'items',
    String nextCursorPath = 'nextCursor',
    String hasMorePath = 'hasMore',
    int? cacheTtlSeconds,
  }) => MpAction(
    'backend.loadMore',
    props: <String, Object?>{
      'requestId': _requiredString(requestId, 'requestId'),
      if (endpoint != null) 'endpoint': _requiredString(endpoint, 'endpoint'),
      'limit': _positiveInt(limit, 'limit'),
      if (initialCursor != null)
        'initialCursor': _requiredString(initialCursor, 'initialCursor'),
      'cursorParam': _requiredString(cursorParam, 'cursorParam'),
      'limitParam': _requiredString(limitParam, 'limitParam'),
      'itemsPath': _requiredString(itemsPath, 'itemsPath'),
      'nextCursorPath': _requiredString(nextCursorPath, 'nextCursorPath'),
      'hasMorePath': _requiredString(hasMorePath, 'hasMorePath'),
      if (cacheTtlSeconds != null)
        'cacheTtlSeconds': _positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
    },
  );
}

/// Mini-program navigation action builders.
final class MpNavigationActions {
  /// Creates mini-program navigation action helpers.
  const MpNavigationActions();

  /// Opens another mini-program screen.
  MpAction openScreen(String screenId, {String? requestId}) =>
      _screenAction('navigation.openScreen', screenId, requestId: requestId);

  /// Replaces the current mini-program screen.
  MpAction replaceScreen(String screenId, {String? requestId}) =>
      _screenAction('navigation.replaceScreen', screenId, requestId: requestId);

  /// Resets the mini-program stack to [screenId].
  MpAction resetStack(String screenId, {String? requestId}) =>
      _screenAction('navigation.resetStack', screenId, requestId: requestId);

  /// Pops one mini-program screen.
  MpAction popScreen({String? requestId}) =>
      _emptyAction('navigation.popScreen', requestId: requestId);

  /// Pops to the mini-program root screen.
  MpAction popToRoot({String? requestId}) =>
      _emptyAction('navigation.popToRoot', requestId: requestId);

  /// Pops to a specific mini-program screen.
  MpAction popToScreen(String screenId, {String? requestId}) =>
      _screenAction('navigation.popToScreen', screenId, requestId: requestId);

  MpAction _screenAction(String type, String screenId, {String? requestId}) =>
      MpAction(
        type,
        props: <String, Object?>{
          'screenId': _requiredString(screenId, 'screenId'),
          if (requestId != null)
            'requestId': _requiredString(requestId, 'requestId'),
        },
      );

  MpAction _emptyAction(String type, {String? requestId}) => MpAction(
    type,
    props: <String, Object?>{
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
    },
  );
}

String _requiredString(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Value cannot be empty.');
  }
  return trimmed;
}

int _positiveInt(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'Value must be positive.');
  }
  return value;
}
