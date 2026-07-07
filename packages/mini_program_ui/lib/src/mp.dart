import 'mp_action.dart';
import 'mp_image.dart';
import 'mp_json.dart';
import 'mp_lazy.dart';
import 'mp_node.dart';
import 'mp_skeleton.dart';
import 'widgets/display_widgets.dart';
import 'widgets/image_widgets.dart';
import 'widgets/layout_widgets.dart';
import 'widgets/list_widgets.dart';
import 'widgets/text_widgets.dart';
import 'widgets/theme_widgets.dart';

/// Author-friendly namespace for Mp widget and action builders.
abstract final class Mp {
  /// Email authentication actions.
  static const auth = MpAuthActions();

  /// Publisher API actions.
  static const backend = MpBackendActions();

  /// Backend search and typeahead helpers.
  static const search = MpSearch();

  /// Mini-program screen navigation actions.
  static const navigation = MpNavigationActions();

  /// Mini-program route actions with params/results support.
  static const router = MpRouterActions();

  /// Mini-program memory state actions.
  static const state = MpStateActions();

  /// Mini-program host-managed cache actions.
  static const cache = MpCacheActions();

  /// Generic action composition helpers.
  static const action = MpActionActions();

  /// Static loading placeholder builders.
  static const skeleton = MpSkeleton();

  /// Lazy-loading section builders.
  static const lazy = MpLazy();

  /// Creates a vertical layout.
  static MpNode column({required List<MpNode> children}) =>
      MpNode('column', children: children);

  /// Creates a horizontal layout.
  static MpNode row({required List<MpNode> children}) =>
      MpNode('row', children: children);

  /// Creates body text.
  static MpNode text(
    String data, {
    num? size,
    String? color,
    String weight = 'regular',
    String align = 'start',
    int? maxLines,
    String overflow = 'clip',
    bool softWrap = true,
    num? lineHeight,
    String textDirection = 'auto',
    String? locale,
    String? variant,
  }) => buildTextNode(
    data,
    size: size,
    color: color,
    weight: weight,
    align: align,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    lineHeight: lineHeight,
    textDirection: textDirection,
    locale: locale,
    variant: variant,
  );

  /// Creates heading text.
  static MpNode heading(
    String data, {
    int level = 1,
    num? size,
    String? color,
    String weight = 'bold',
    String align = 'start',
    int? maxLines,
    String overflow = 'clip',
    bool softWrap = true,
    num? lineHeight,
    String textDirection = 'auto',
    String? locale,
    String? variant,
  }) => buildHeadingNode(
    data,
    level: level,
    size: size,
    color: color,
    weight: weight,
    align: align,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    lineHeight: lineHeight,
    textDirection: textDirection,
    locale: locale,
    variant: variant,
  );

  /// Applies lightweight theme tokens to [child].
  static MpNode theme({
    required MpNode child,
    Map<String, String>? colors,
    Map<String, Map<String, Object?>>? typography,
  }) => buildThemeNode(child: child, colors: colors, typography: typography);

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

  /// Creates padding around [child].
  static MpNode padding({
    required MpNode child,
    num? all,
    num? horizontal,
    num? vertical,
    num? left,
    num? top,
    num? right,
    num? bottom,
  }) => buildPaddingNode(
    child: child,
    all: all,
    horizontal: horizontal,
    vertical: vertical,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
  );

  /// Aligns [child] within the available space.
  static MpNode align({required MpNode child, String alignment = 'center'}) =>
      buildAlignNode(child: child, alignment: alignment);

  /// Centers [child] within the available space.
  static MpNode center({required MpNode child}) =>
      buildCenterNode(child: child);

  /// Creates flexible empty space inside Mp row or column.
  static MpNode spacer({int flex = 1}) => buildSpacerNode(flex: flex);

  /// Expands [child] inside a bounded Mp row or column.
  static MpNode expanded({required MpNode child, int flex = 1}) =>
      buildExpandedNode(child: child, flex: flex);

  /// Sizes [child] flexibly inside a bounded Mp row or column.
  static MpNode flexible({
    required MpNode child,
    int flex = 1,
    String fit = 'loose',
  }) => buildFlexibleNode(child: child, flex: flex, fit: fit);

  /// Creates a styled container around [child].
  static MpNode container({
    required MpNode child,
    num? width,
    num? height,
    num? paddingAll,
    num? paddingHorizontal,
    num? paddingVertical,
    num? paddingLeft,
    num? paddingTop,
    num? paddingRight,
    num? paddingBottom,
    String? backgroundColor,
    String? borderColor,
    num? borderWidth,
    num? borderRadius,
  }) => buildContainerNode(
    child: child,
    width: width,
    height: height,
    paddingAll: paddingAll,
    paddingHorizontal: paddingHorizontal,
    paddingVertical: paddingVertical,
    paddingLeft: paddingLeft,
    paddingTop: paddingTop,
    paddingRight: paddingRight,
    paddingBottom: paddingBottom,
    backgroundColor: backgroundColor,
    borderColor: borderColor,
    borderWidth: borderWidth,
    borderRadius: borderRadius,
  );

  /// Creates a nested or section-level scroll view.
  static MpNode scrollView({
    required MpNode child,
    num? paddingAll,
    num? paddingHorizontal,
    num? paddingVertical,
    num? paddingLeft,
    num? paddingTop,
    num? paddingRight,
    num? paddingBottom,
  }) => buildScrollViewNode(
    child: child,
    paddingAll: paddingAll,
    paddingHorizontal: paddingHorizontal,
    paddingVertical: paddingVertical,
    paddingLeft: paddingLeft,
    paddingTop: paddingTop,
    paddingRight: paddingRight,
    paddingBottom: paddingBottom,
  );

  /// Creates a small or medium section-level list.
  static MpNode listView({
    required List<MpNode> children,
    num spacing = 0,
    num? paddingAll,
    num? paddingHorizontal,
    num? paddingVertical,
    num? paddingLeft,
    num? paddingTop,
    num? paddingRight,
    num? paddingBottom,
  }) => buildListViewNode(
    children: children,
    spacing: spacing,
    paddingAll: paddingAll,
    paddingHorizontal: paddingHorizontal,
    paddingVertical: paddingVertical,
    paddingLeft: paddingLeft,
    paddingTop: paddingTop,
    paddingRight: paddingRight,
    paddingBottom: paddingBottom,
  );

  /// Repeats [itemTemplate] for every item resolved by [source].
  static MpNode repeat({
    required String source,
    required MpNode itemTemplate,
    MpNode? empty,
    MpNode? separator,
    num spacing = 0,
    int limit = 100,
  }) => buildRepeatNode(
    source: source,
    itemTemplate: itemTemplate,
    empty: empty,
    separator: separator,
    spacing: spacing,
    limit: limit,
  );

  /// Alias for [repeat].
  static MpNode forEach({
    required String source,
    required MpNode itemTemplate,
    MpNode? empty,
    MpNode? separator,
    num spacing = 0,
    int limit = 100,
  }) => repeat(
    source: source,
    itemTemplate: itemTemplate,
    empty: empty,
    separator: separator,
    spacing: spacing,
    limit: limit,
  );

  /// Insets [child] away from unsafe display areas.
  static MpNode safeArea({
    required MpNode child,
    bool left = true,
    bool top = true,
    bool right = true,
    bool bottom = true,
  }) => buildSafeAreaNode(
    child: child,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
  );

  /// Shows or hides [child] while optionally preserving layout/state.
  static MpNode visibility({
    required MpNode child,
    bool visible = true,
    bool maintainSize = false,
    bool maintainState = false,
  }) => buildVisibilityNode(
    child: child,
    visible: visible,
    maintainSize: maintainSize,
    maintainState: maintainState,
  );

  /// Paints [child] with the provided opacity.
  static MpNode opacity({
    required MpNode child,
    num opacity = 1,
    bool alwaysIncludeSemantics = false,
  }) => buildOpacityNode(
    child: child,
    opacity: opacity,
    alwaysIncludeSemantics: alwaysIncludeSemantics,
  );

  /// Sizes [child] to a fixed width-to-height ratio.
  static MpNode aspectRatio({
    required MpNode child,
    required num aspectRatio,
  }) => buildAspectRatioNode(child: child, aspectRatio: aspectRatio);

  /// Overlays [children] in paint order.
  static MpNode stack({
    required List<MpNode> children,
    String alignment = 'topLeft',
    bool clip = true,
  }) => buildStackNode(children: children, alignment: alignment, clip: clip);

  /// Positions [child] when used directly inside Mp.stack.
  static MpNode positioned({
    required MpNode child,
    num? left,
    num? top,
    num? right,
    num? bottom,
    num? width,
    num? height,
  }) => buildPositionedNode(
    child: child,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    width: width,
    height: height,
  );

  /// Creates a horizontal divider.
  static MpNode divider({
    num thickness = 1,
    num spacing = 12,
    String color = '#E5E7EB',
  }) => buildDividerNode(thickness: thickness, spacing: spacing, color: color);

  /// Creates an icon from the Mp icon allowlist.
  static MpNode icon(
    String name, {
    num size = 20,
    String? color,
    String? semanticLabel,
  }) => buildIconNode(
    name,
    size: size,
    color: color,
    semanticLabel: semanticLabel,
  );

  /// Creates a tone-colored alert message.
  static MpNode alert({
    required String title,
    String? message,
    String tone = 'info',
    String? icon,
  }) => buildAlertNode(title: title, message: message, tone: tone, icon: icon);

  /// Creates a circular avatar from an image URL, initials, or icon.
  static MpNode avatar({
    String? imageUrl,
    String? initials,
    String? icon,
    num size = 40,
    String? semanticLabel,
  }) => buildAvatarNode(
    imageUrl: imageUrl,
    initials: initials,
    icon: icon,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Creates a fixed-column grid.
  static MpNode grid({
    required List<MpNode> children,
    int columns = 2,
    num spacing = 8,
  }) => buildGridNode(children: children, columns: columns, spacing: spacing);

  /// Creates a wrapping layout for chips, badges, and compact content.
  static MpNode wrap({
    required List<MpNode> children,
    num spacing = 8,
    num runSpacing = 8,
  }) => buildWrapNode(
    children: children,
    spacing: spacing,
    runSpacing: runSpacing,
  );

  /// Creates a linear progress indicator.
  static MpNode progress({
    required num value,
    num max = 1,
    String? label,
    String tone = 'info',
  }) => buildProgressNode(value: value, max: max, label: label, tone: tone);

  /// Creates an empty-state placeholder with an optional action.
  static MpNode emptyState({
    required String title,
    String? message,
    String icon = 'info',
    String? actionLabel,
    MpAction? action,
  }) => buildEmptyStateNode(
    title: title,
    message: message,
    icon: icon,
    actionLabel: actionLabel,
    action: action,
  );

  /// Creates an async image node.
  static MpNode image({
    required String src,
    MpImageSource source = MpImageSource.auto,
    double? width,
    double? height,
    MpImageFit fit = MpImageFit.cover,
    MpNode? placeholder,
    MpNode? error,
    String? semanticLabel,
    Map<String, String>? headers,
    bool cache = true,
    String? cacheKey,
    Duration fadeInDuration = const Duration(milliseconds: 200),
    String? alt,
  }) => buildImageNode(
    src: src,
    source: source,
    width: width,
    height: height,
    fit: fit,
    placeholder: placeholder,
    error: error,
    semanticLabel: semanticLabel,
    headers: headers,
    cache: cache,
    cacheKey: cacheKey,
    fadeInDuration: fadeInDuration,
    alt: alt,
  );

  /// Creates a simple card container.
  static MpNode card({required MpNode child}) =>
      MpNode('card', children: <MpNode>[child]);

  /// Creates a single-line text input controlled by the SDK form state.
  static MpNode textInput({
    required String name,
    required String label,
    String? hint,
    String? initialValue,
    bool required = false,
    int? minLength,
    int? maxLength,
    bool obscureText = false,
    String keyboardType = 'text',
  }) => MpNode(
    'textInput',
    props: _inputProps(
      name: name,
      label: label,
      hint: hint,
      initialValue: initialValue,
      required: required,
      minLength: minLength,
      maxLength: maxLength,
      obscureText: obscureText,
      keyboardType: keyboardType,
    ),
  );

  /// Creates a state-driven backend search input for typeahead results.
  static MpNode searchInput({
    required String stateKey,
    required String targetState,
    required String endpoint,
    String? requestId,
    String queryParam = 'q',
    String limitParam = 'limit',
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    String label = 'Search',
    String? hint,
    String? initialValue,
    int minLength = 2,
    int limit = 20,
    Duration debounce = const Duration(milliseconds: 300),
    String? statusState,
    String? errorState,
    bool clearResultsBelowMinLength = true,
    int? cacheTtlSeconds,
  }) => MpNode(
    'searchInput',
    props: _searchInputProps(
      stateKey: stateKey,
      targetState: targetState,
      endpoint: endpoint,
      requestId: requestId,
      queryParam: queryParam,
      limitParam: limitParam,
      method: method,
      body: body,
      label: label,
      hint: hint,
      initialValue: initialValue,
      minLength: minLength,
      limit: limit,
      debounce: debounce,
      statusState: statusState,
      errorState: errorState,
      clearResultsBelowMinLength: clearResultsBelowMinLength,
      cacheTtlSeconds: cacheTtlSeconds,
    ),
  );

  /// Creates a multi-line text input controlled by the SDK form state.
  static MpNode textArea({
    required String name,
    required String label,
    String? hint,
    String? initialValue,
    bool required = false,
    int? minLength,
    int? maxLength,
    int minLines = 3,
    int maxLines = 6,
  }) {
    if (minLines <= 0) {
      throw ArgumentError.value(
        minLines,
        'minLines',
        'Value must be positive.',
      );
    }
    if (maxLines < minLines) {
      throw ArgumentError.value(
        maxLines,
        'maxLines',
        'Value must be greater than or equal to minLines.',
      );
    }
    return MpNode(
      'textArea',
      props: <String, Object?>{
        ..._inputProps(
          name: name,
          label: label,
          hint: hint,
          initialValue: initialValue,
          required: required,
          minLength: minLength,
          maxLength: maxLength,
          includeKeyboardType: false,
        ),
        'minLines': minLines,
        'maxLines': maxLines,
      },
    );
  }

  /// Creates a select menu controlled by the SDK form state.
  static MpNode dropdown({
    required String name,
    required String label,
    required List<MpOption> options,
    String? hint,
    String? initialValue,
    bool required = false,
  }) {
    final normalizedOptions = _requiredOptions(options);
    final normalizedInitialValue = initialValue == null
        ? null
        : _requiredString(initialValue, 'initialValue');
    _validateInitialOptionValue(normalizedOptions, normalizedInitialValue);
    return MpNode(
      'dropdown',
      props: <String, Object?>{
        'name': _requiredString(name, 'name'),
        'label': _requiredString(label, 'label'),
        if (hint != null) 'hint': _requiredString(hint, 'hint'),
        'options': normalizedOptions,
        if (normalizedInitialValue != null)
          'initialValue': normalizedInitialValue,
        if (required) 'required': true,
      },
    );
  }

  /// Creates a boolean checkbox controlled by the SDK form state.
  static MpNode checkbox({
    required String name,
    required String label,
    bool initialValue = false,
    bool requiredTrue = false,
  }) => MpNode(
    'checkbox',
    props: <String, Object?>{
      'name': _requiredString(name, 'name'),
      'label': _requiredString(label, 'label'),
      if (initialValue) 'initialValue': true,
      if (requiredTrue) 'requiredTrue': true,
    },
  );

  /// Creates a radio option group controlled by the SDK form state.
  static MpNode radioGroup({
    required String name,
    required String label,
    required List<MpOption> options,
    String? initialValue,
    bool required = false,
  }) {
    final normalizedOptions = _requiredOptions(options);
    final normalizedInitialValue = initialValue == null
        ? null
        : _requiredString(initialValue, 'initialValue');
    _validateInitialOptionValue(normalizedOptions, normalizedInitialValue);
    return MpNode(
      'radioGroup',
      props: <String, Object?>{
        'name': _requiredString(name, 'name'),
        'label': _requiredString(label, 'label'),
        'options': normalizedOptions,
        if (normalizedInitialValue != null)
          'initialValue': normalizedInitialValue,
        if (required) 'required': true,
      },
    );
  }

  /// Creates an SDK-owned form scope.
  static MpNode form({String id = 'form', required List<MpNode> children}) =>
      MpNode(
        'form',
        props: <String, Object?>{'id': _requiredString(id, 'id')},
        children: _requiredChildren(children, 'children'),
      );

  /// Creates a submit button for the nearest Mp form.
  static MpNode formSubmit({
    required String label,
    required String endpoint,
    String? requestId,
    String method = 'POST',
    Map<String, Object?> body = const <String, Object?>{},
    int? cacheTtlSeconds,
    MpAction? onSuccess,
    MpAction? onError,
  }) => MpNode(
    'formSubmit',
    props: <String, Object?>{
      'label': _requiredString(label, 'label'),
      'endpoint': _requiredString(endpoint, 'endpoint'),
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
      'method': _requiredString(method, 'method'),
      if (body.isNotEmpty) 'body': body,
      if (cacheTtlSeconds != null)
        'cacheTtlSeconds': _positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
      if (onSuccess != null) 'onSuccess': onSuccess,
      if (onError != null) 'onError': onError,
    },
  );

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

  /// Creates a compact list row.
  static MpNode listTile({
    required String title,
    String? subtitle,
    String? leadingIcon,
    String? trailingIcon,
    String? badge,
    MpAction? action,
  }) => buildListTileNode(
    title: title,
    subtitle: subtitle,
    leadingIcon: leadingIcon,
    trailingIcon: trailingIcon,
    badge: badge,
    action: action,
  );

  /// Creates a small status or filter chip.
  static MpNode chip({
    required String label,
    String tone = 'neutral',
    String? leadingIcon,
    MpAction? action,
  }) => buildChipNode(
    label: label,
    tone: tone,
    leadingIcon: leadingIcon,
    action: action,
  );

  /// Creates a small status badge.
  static MpNode badge({required String label, String tone = 'info'}) =>
      buildBadgeNode(label: label, tone: tone);

  /// Creates a titled section with an optional action.
  static MpNode section({
    required String title,
    String? subtitle,
    required MpNode child,
    String? actionLabel,
    MpAction? action,
  }) => buildSectionNode(
    title: title,
    subtitle: subtitle,
    child: child,
    actionLabel: actionLabel,
    action: action,
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

  /// Creates a Publisher API data builder.
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

  /// Creates a paged Publisher API data builder.
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

  /// Rebuilds [child] when any declared state key changes.
  static MpNode stateBuilder({
    required List<String> keys,
    required MpNode child,
  }) => MpNode(
    'stateBuilder',
    props: <String, Object?>{'keys': _requiredStateKeys(keys), 'child': child},
  );

  /// Creates a toast/snackbar-style UI feedback action.
  static MpAction toast({required String message, int durationMs = 2400}) =>
      MpAction(
        'ui.toast',
        props: <String, Object?>{
          'message': _requiredString(message, 'message'),
          'durationMs': _positiveInt(durationMs, 'durationMs'),
        },
      );

  /// Creates a modal confirmation/info dialog action.
  static MpAction dialog({
    String? title,
    required String message,
    String confirmLabel = 'OK',
  }) => MpAction(
    'ui.dialog',
    props: <String, Object?>{
      if (title != null) 'title': _requiredString(title, 'title'),
      'message': _requiredString(message, 'message'),
      'confirmLabel': _requiredString(confirmLabel, 'confirmLabel'),
    },
  );
}

/// Mini-program memory state action builders.
final class MpStateActions {
  /// Creates state action helpers.
  const MpStateActions();

  /// Creates or replaces [key] with [value].
  MpAction put(String key, Object? value) => MpAction(
    'state.put',
    props: <String, Object?>{
      'key': _requiredStateKey(key, 'key'),
      'value': value,
    },
  );

  /// Replaces [key] with [value].
  MpAction set(String key, Object? value) => MpAction(
    'state.set',
    props: <String, Object?>{
      'key': _requiredStateKey(key, 'key'),
      'value': value,
    },
  );

  /// Adds [by] to the numeric state value at [key].
  MpAction increment(String key, {num by = 1}) => MpAction(
    'state.increment',
    props: <String, Object?>{'key': _requiredStateKey(key, 'key'), 'by': by},
  );

  /// Removes [key] from memory state.
  MpAction remove(String key) => MpAction(
    'state.remove',
    props: <String, Object?>{'key': _requiredStateKey(key, 'key')},
  );

  /// Clears all memory state for the current mini-program instance.
  MpAction clear() => MpAction('state.clear');
}

/// Mini-program cache action builders.
final class MpCacheActions {
  /// Creates cache action helpers.
  const MpCacheActions();

  /// Runtime-only cache. Hosts usually clear this when the mini-program exits.
  MpCacheBucketActions get memory => const MpCacheBucketActions._('memory');

  /// General persistent data cache.
  MpCacheBucketActions get data => const MpCacheBucketActions._('data');

  /// Image metadata or image-related cache controlled by host policy.
  MpCacheBucketActions get image => const MpCacheBucketActions._('image');

  /// Mini-program UI state cache, such as calculator history or selected tabs.
  MpCacheBucketActions get state => const MpCacheBucketActions._('state');

  /// Video metadata or video-related cache controlled by host policy.
  MpCacheBucketActions get video => const MpCacheBucketActions._('video');

  /// Writes [value] to the selected cache [bucket].
  MpAction set(
    String key,
    Object? value, {
    String bucket = 'data',
    String? requestId,
    Duration? ttl,
    String priority = 'normal',
  }) => MpCacheBucketActions._(
    _cacheBucket(bucket),
  ).set(key, value, requestId: requestId, ttl: ttl, priority: priority);

  /// Reads [key] from the selected cache [bucket].
  MpAction get(
    String key, {
    String bucket = 'data',
    String? targetState,
    bool skipMissing = false,
    String? requestId,
  }) => MpCacheBucketActions._(_cacheBucket(bucket)).get(
    key,
    targetState: targetState,
    skipMissing: skipMissing,
    requestId: requestId,
  );

  /// Checks whether [key] exists in the selected cache [bucket].
  MpAction has(
    String key, {
    String bucket = 'data',
    String? targetState,
    String? requestId,
  }) => MpCacheBucketActions._(
    _cacheBucket(bucket),
  ).has(key, targetState: targetState, requestId: requestId);

  /// Removes [key] from the selected cache [bucket].
  MpAction remove(String key, {String bucket = 'data', String? requestId}) =>
      MpCacheBucketActions._(
        _cacheBucket(bucket),
      ).remove(key, requestId: requestId);

  /// Clears one selected cache [bucket], or all allowed buckets when omitted.
  MpAction clear({String? bucket, String? requestId}) {
    if (bucket == null) {
      return MpAction(
        'cache.clear',
        props: <String, Object?>{
          if (requestId != null)
            'requestId': _requiredString(requestId, 'requestId'),
        },
      );
    }
    return MpCacheBucketActions._(
      _cacheBucket(bucket),
    ).clear(requestId: requestId);
  }
}

/// Mini-program cache action builders for a fixed bucket.
final class MpCacheBucketActions {
  const MpCacheBucketActions._(this._bucket);

  final String _bucket;

  /// Writes [value] to [key] in this bucket.
  MpAction set(
    String key,
    Object? value, {
    String? requestId,
    Duration? ttl,
    String priority = 'normal',
  }) => MpAction(
    'cache.set',
    props: <String, Object?>{
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
      'key': _requiredCacheKey(key, 'key'),
      'bucket': _bucket,
      'value': value,
      if (ttl != null) 'ttlMs': _positiveDurationMs(ttl, 'ttl'),
      'priority': _cachePriority(priority),
    },
  );

  /// Reads [key] and optionally writes the result to [targetState].
  MpAction get(
    String key, {
    String? targetState,
    bool skipMissing = false,
    String? requestId,
  }) => MpAction(
    'cache.get',
    props: <String, Object?>{
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
      'key': _requiredCacheKey(key, 'key'),
      'bucket': _bucket,
      if (targetState != null)
        'targetState': _requiredStateKey(targetState, 'targetState'),
      if (skipMissing) 'skipMissing': true,
    },
  );

  /// Checks whether [key] exists and optionally writes the result to state.
  MpAction has(String key, {String? targetState, String? requestId}) =>
      MpAction(
        'cache.has',
        props: <String, Object?>{
          if (requestId != null)
            'requestId': _requiredString(requestId, 'requestId'),
          'key': _requiredCacheKey(key, 'key'),
          'bucket': _bucket,
          if (targetState != null)
            'targetState': _requiredStateKey(targetState, 'targetState'),
        },
      );

  /// Removes [key] from this bucket.
  MpAction remove(String key, {String? requestId}) => MpAction(
    'cache.remove',
    props: <String, Object?>{
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
      'key': _requiredCacheKey(key, 'key'),
      'bucket': _bucket,
    },
  );

  /// Clears this bucket.
  MpAction clear({String? requestId}) => MpAction(
    'cache.clear',
    props: <String, Object?>{
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
      'bucket': _bucket,
    },
  );
}

/// Mini-program router action builders with route params/results.
final class MpRouterActions {
  /// Creates router action helpers.
  const MpRouterActions();

  /// Pushes [screenId] and exposes [params] under `{{route.*}}`.
  MpAction push(
    String screenId, {
    Map<String, Object?> params = const <String, Object?>{},
    String? requestId,
  }) => _screenAction(
    'router.push',
    screenId,
    params: params,
    requestId: requestId,
  );

  /// Replaces the active screen.
  MpAction replace(
    String screenId, {
    Map<String, Object?> params = const <String, Object?>{},
    String? requestId,
  }) => _screenAction(
    'router.replace',
    screenId,
    params: params,
    requestId: requestId,
  );

  /// Resets the stack to [screenId].
  MpAction reset(
    String screenId, {
    Map<String, Object?> params = const <String, Object?>{},
    String? requestId,
  }) => _screenAction(
    'router.reset',
    screenId,
    params: params,
    requestId: requestId,
  );

  /// Pops the current screen and returns [result] to the revealed screen.
  MpAction pop({
    Map<String, Object?> result = const <String, Object?>{},
    String? requestId,
  }) => _resultAction('router.pop', result: result, requestId: requestId);

  /// Pops to the root screen and returns [result].
  MpAction popToRoot({
    Map<String, Object?> result = const <String, Object?>{},
    String? requestId,
  }) => _resultAction('router.popToRoot', result: result, requestId: requestId);

  /// Pops to [screenId] and returns [result].
  MpAction popToScreen(
    String screenId, {
    Map<String, Object?> result = const <String, Object?>{},
    String? requestId,
  }) => MpAction(
    'router.popToScreen',
    props: <String, Object?>{
      'screenId': _requiredString(screenId, 'screenId'),
      if (result.isNotEmpty) 'result': result,
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
    },
  );

  MpAction _screenAction(
    String type,
    String screenId, {
    required Map<String, Object?> params,
    String? requestId,
  }) => MpAction(
    type,
    props: <String, Object?>{
      'screenId': _requiredString(screenId, 'screenId'),
      if (params.isNotEmpty) 'params': params,
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
    },
  );

  MpAction _resultAction(
    String type, {
    required Map<String, Object?> result,
    String? requestId,
  }) => MpAction(
    type,
    props: <String, Object?>{
      if (result.isNotEmpty) 'result': result,
      if (requestId != null)
        'requestId': _requiredString(requestId, 'requestId'),
    },
  );
}

/// Generic action composition helpers.
final class MpActionActions {
  /// Creates action composition helpers.
  const MpActionActions();

  /// Runs [steps] in order and stops when a step fails.
  MpAction sequence(List<MpAction> steps) => MpAction(
    'sequence',
    props: <String, Object?>{'steps': _requiredActions(steps)},
  );
}

/// Serializable option used by Mp dropdown and radioGroup controls.
final class MpOption implements MpJsonEncodable {
  /// Creates a serializable form option.
  const MpOption({required this.value, required this.label});

  /// Wire value submitted through form state.
  final String value;

  /// User-facing label rendered in the SDK.
  final String label;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'label': _requiredString(label, 'label'),
    'value': _requiredString(value, 'value'),
  };
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

/// Publisher API action builders.
final class MpBackendActions {
  /// Creates Publisher API action helpers.
  const MpBackendActions();

  /// Calls a Publisher API endpoint without storing state.
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

  /// Queries a Publisher API endpoint into SDK backend state.
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

  /// Loads the next page for a paged Publisher API query.
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

/// Backend search and typeahead helper builders.
final class MpSearch {
  /// Creates backend search helper builders.
  const MpSearch();

  /// Creates a state-driven backend search input for typeahead results.
  MpNode input({
    required String stateKey,
    required String targetState,
    required String endpoint,
    String? requestId,
    String queryParam = 'q',
    String limitParam = 'limit',
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    String label = 'Search',
    String? hint,
    String? initialValue,
    int minLength = 2,
    int limit = 20,
    Duration debounce = const Duration(milliseconds: 300),
    String? statusState,
    String? errorState,
    bool clearResultsBelowMinLength = true,
    int? cacheTtlSeconds,
  }) => Mp.searchInput(
    stateKey: stateKey,
    targetState: targetState,
    endpoint: endpoint,
    requestId: requestId,
    queryParam: queryParam,
    limitParam: limitParam,
    method: method,
    body: body,
    label: label,
    hint: hint,
    initialValue: initialValue,
    minLength: minLength,
    limit: limit,
    debounce: debounce,
    statusState: statusState,
    errorState: errorState,
    clearResultsBelowMinLength: clearResultsBelowMinLength,
    cacheTtlSeconds: cacheTtlSeconds,
  );

  /// Clears the current backend search query, results, status, and error state.
  MpAction clear({
    required String queryState,
    required String targetState,
    String? statusState,
    String? errorState,
  }) {
    return MpAction(
      'search.clear',
      props: <String, Object?>{
        'queryState': _requiredStateKey(queryState, 'queryState'),
        'targetState': _requiredStateKey(targetState, 'targetState'),
        if (statusState != null)
          'statusState': _requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': _requiredStateKey(errorState, 'errorState'),
      },
    );
  }

  /// Refreshes the first backend search page for the current query.
  MpAction refresh({
    required String queryState,
    required String targetState,
    required String endpoint,
    String? requestId,
    String queryParam = 'q',
    String limitParam = 'limit',
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    int limit = 20,
    String itemsPath = 'items',
    String nextCursorPath = 'nextCursor',
    String hasMorePath = 'hasMore',
    String? statusState,
    String? errorState,
    int? cacheTtlSeconds,
    bool skipWhenNoQuery = true,
  }) {
    final normalizedQueryState = _requiredStateKey(queryState, 'queryState');
    return MpAction(
      'search.refresh',
      props: <String, Object?>{
        'queryState': normalizedQueryState,
        'targetState': _requiredStateKey(targetState, 'targetState'),
        'endpoint': _stableString(endpoint, 'endpoint'),
        'requestId': requestId == null
            ? '${_generatedSearchRequestId(normalizedQueryState)}_refresh'
            : _stableString(requestId, 'requestId'),
        'queryParam': _fieldName(queryParam, 'queryParam'),
        'limitParam': _fieldName(limitParam, 'limitParam'),
        'method': _searchMethod(method),
        if (body.isNotEmpty) 'body': body,
        'limit': _searchLimit(limit),
        'itemsPath': _stableString(itemsPath, 'itemsPath'),
        'nextCursorPath': _stableString(nextCursorPath, 'nextCursorPath'),
        'hasMorePath': _stableString(hasMorePath, 'hasMorePath'),
        if (statusState != null)
          'statusState': _requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': _requiredStateKey(errorState, 'errorState'),
        if (cacheTtlSeconds != null)
          'cacheTtlSeconds': _positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
        if (!skipWhenNoQuery) 'skipWhenNoQuery': false,
      },
    );
  }

  /// Loads the next backend search page into an existing search result state.
  MpAction loadMore({
    required String queryState,
    required String targetState,
    required String endpoint,
    String? requestId,
    String queryParam = 'q',
    String cursorParam = 'cursor',
    String limitParam = 'limit',
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    int limit = 20,
    String itemsPath = 'items',
    String nextCursorPath = 'nextCursor',
    String hasMorePath = 'hasMore',
    String? statusState,
    String? errorState,
    int? cacheTtlSeconds,
    bool skipWhenNoQuery = true,
  }) {
    final normalizedQueryState = _requiredStateKey(queryState, 'queryState');
    return MpAction(
      'search.loadMore',
      props: <String, Object?>{
        'queryState': normalizedQueryState,
        'targetState': _requiredStateKey(targetState, 'targetState'),
        'endpoint': _stableString(endpoint, 'endpoint'),
        'requestId': requestId == null
            ? '${_generatedSearchRequestId(normalizedQueryState)}_load_more'
            : _stableString(requestId, 'requestId'),
        'queryParam': _fieldName(queryParam, 'queryParam'),
        'cursorParam': _fieldName(cursorParam, 'cursorParam'),
        'limitParam': _fieldName(limitParam, 'limitParam'),
        'method': _searchMethod(method),
        if (body.isNotEmpty) 'body': body,
        'limit': _searchLimit(limit),
        'itemsPath': _stableString(itemsPath, 'itemsPath'),
        'nextCursorPath': _stableString(nextCursorPath, 'nextCursorPath'),
        'hasMorePath': _stableString(hasMorePath, 'hasMorePath'),
        if (statusState != null)
          'statusState': _requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': _requiredStateKey(errorState, 'errorState'),
        if (cacheTtlSeconds != null)
          'cacheTtlSeconds': _positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
        if (!skipWhenNoQuery) 'skipWhenNoQuery': false,
      },
    );
  }
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

String _stableString(String value, String name) {
  final stable = _requiredString(value, name);
  if (stable.contains('{{') || stable.contains('}}')) {
    throw ArgumentError.value(value, name, 'Value cannot contain bindings.');
  }
  return stable;
}

int _positiveInt(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'Value must be positive.');
  }
  return value;
}

int _positiveDurationMs(Duration value, String name) {
  final milliseconds = value.inMilliseconds;
  if (milliseconds <= 0) {
    throw ArgumentError.value(value, name, 'Duration must be positive.');
  }
  return milliseconds;
}

int _nonNegativeInt(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'Value cannot be negative.');
  }
  return value;
}

int _searchLimit(int value) {
  if (value <= 0 || value > 100) {
    throw ArgumentError.value(
      value,
      'limit',
      'Search limit must be between 1 and 100.',
    );
  }
  return value;
}

String _searchMethod(String value) {
  final method = _requiredString(value, 'method').toUpperCase();
  if (method != 'GET' && method != 'POST') {
    throw ArgumentError.value(
      value,
      'method',
      'Search method must be GET or POST.',
    );
  }
  return method;
}

String _fieldName(String value, String name) {
  final normalized = _requiredString(value, name);
  if (!_fieldNamePattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Value must match ^[a-z][a-z0-9_]*\$.',
    );
  }
  return normalized;
}

String _generatedSearchRequestId(String stateKey) {
  return 'search_${stateKey.replaceAll('.', '_')}';
}

Map<String, Object?> _searchInputProps({
  required String stateKey,
  required String targetState,
  required String endpoint,
  String? requestId,
  String queryParam = 'q',
  String limitParam = 'limit',
  String method = 'GET',
  Map<String, Object?> body = const <String, Object?>{},
  String label = 'Search',
  String? hint,
  String? initialValue,
  int minLength = 2,
  int limit = 20,
  Duration debounce = const Duration(milliseconds: 300),
  String? statusState,
  String? errorState,
  bool clearResultsBelowMinLength = true,
  int? cacheTtlSeconds,
}) {
  final normalizedStateKey = _requiredStateKey(stateKey, 'stateKey');
  return <String, Object?>{
    'stateKey': normalizedStateKey,
    'targetState': _requiredStateKey(targetState, 'targetState'),
    'endpoint': _stableString(endpoint, 'endpoint'),
    'requestId': requestId == null
        ? _generatedSearchRequestId(normalizedStateKey)
        : _stableString(requestId, 'requestId'),
    'queryParam': _fieldName(queryParam, 'queryParam'),
    'limitParam': _fieldName(limitParam, 'limitParam'),
    'method': _searchMethod(method),
    if (body.isNotEmpty) 'body': body,
    'label': _requiredString(label, 'label'),
    if (hint != null) 'hint': _requiredString(hint, 'hint'),
    if (initialValue != null) 'initialValue': initialValue,
    'minLength': _nonNegativeInt(minLength, 'minLength'),
    'limit': _searchLimit(limit),
    'debounceMs': _nonNegativeInt(debounce.inMilliseconds, 'debounceMs'),
    if (statusState != null)
      'statusState': _requiredStateKey(statusState, 'statusState'),
    if (errorState != null)
      'errorState': _requiredStateKey(errorState, 'errorState'),
    if (!clearResultsBelowMinLength) 'clearResultsBelowMinLength': false,
    if (cacheTtlSeconds != null)
      'cacheTtlSeconds': _positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
  };
}

Map<String, Object?> _inputProps({
  required String name,
  required String label,
  String? hint,
  String? initialValue,
  bool required = false,
  int? minLength,
  int? maxLength,
  bool obscureText = false,
  String keyboardType = 'text',
  bool includeKeyboardType = true,
}) {
  if (minLength != null && minLength < 0) {
    throw ArgumentError.value(
      minLength,
      'minLength',
      'Value cannot be negative.',
    );
  }
  if (maxLength != null && maxLength <= 0) {
    throw ArgumentError.value(
      maxLength,
      'maxLength',
      'Value must be positive.',
    );
  }
  if (minLength != null && maxLength != null && minLength > maxLength) {
    throw ArgumentError.value(
      minLength,
      'minLength',
      'Value must be less than or equal to maxLength.',
    );
  }
  return <String, Object?>{
    'name': _requiredString(name, 'name'),
    'label': _requiredString(label, 'label'),
    if (hint != null) 'hint': _requiredString(hint, 'hint'),
    if (initialValue != null) 'initialValue': initialValue,
    if (required) 'required': true,
    if (minLength != null) 'minLength': minLength,
    if (maxLength != null) 'maxLength': maxLength,
    if (includeKeyboardType && obscureText) 'obscureText': true,
    if (includeKeyboardType)
      'keyboardType': _requiredString(keyboardType, 'keyboardType'),
  };
}

List<MpOption> _requiredOptions(List<MpOption> options) {
  if (options.isEmpty) {
    throw ArgumentError.value(options, 'options', 'Options cannot be empty.');
  }
  final values = <String>{};
  for (final option in options) {
    final value = _requiredString(option.value, 'option.value');
    _requiredString(option.label, 'option.label');
    if (!values.add(value)) {
      throw ArgumentError.value(
        value,
        'option.value',
        'Option values must be unique.',
      );
    }
  }
  return options;
}

List<MpNode> _requiredChildren(List<MpNode> children, String name) {
  if (children.isEmpty) {
    throw ArgumentError.value(children, name, 'Children cannot be empty.');
  }
  return children;
}

List<MpAction> _requiredActions(List<MpAction> actions) {
  if (actions.isEmpty) {
    throw ArgumentError.value(actions, 'steps', 'Actions cannot be empty.');
  }
  return actions;
}

List<String> _requiredStateKeys(List<String> keys) {
  if (keys.isEmpty) {
    throw ArgumentError.value(keys, 'keys', 'State keys cannot be empty.');
  }
  return keys
      .map((key) => _requiredStateKey(key, 'key'))
      .toList(growable: false);
}

String _requiredStateKey(String value, String name) {
  final normalized = _requiredString(value, name);
  if (!_stateKeyPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Mp state keys must be lowercase dot paths.',
    );
  }
  for (final segment in normalized.split('.')) {
    final compact = segment.replaceAll('_', '').toLowerCase();
    if (_blockedStateSegments.contains(compact)) {
      throw ArgumentError.value(
        value,
        name,
        'Mp state keys cannot contain secret-like segments.',
      );
    }
  }
  return normalized;
}

String _requiredCacheKey(String value, String name) {
  final normalized = _stableString(value, name);
  if (_unsafeCacheKeyPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Mp cache keys cannot contain path traversal, separators, or file path markers.',
    );
  }
  return normalized;
}

String _cacheBucket(String value) {
  final normalized = _stableString(value, 'bucket');
  if (!_allowedCacheBuckets.contains(normalized)) {
    throw ArgumentError.value(
      value,
      'bucket',
      'Mp cache bucket must be memory, data, image, state, or video.',
    );
  }
  return normalized;
}

String _cachePriority(String value) {
  final normalized = _stableString(value, 'priority');
  if (!_allowedCachePriorities.contains(normalized)) {
    throw ArgumentError.value(
      value,
      'priority',
      'Mp cache priority must be low, normal, or high.',
    );
  }
  return normalized;
}

void _validateInitialOptionValue(List<MpOption> options, String? value) {
  if (value == null) {
    return;
  }
  if (!options.any((option) => option.value == value)) {
    throw ArgumentError.value(
      value,
      'initialValue',
      'Value must match one option value.',
    );
  }
}

final RegExp _stateKeyPattern = RegExp(
  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$',
);

final RegExp _fieldNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');

final RegExp _unsafeCacheKeyPattern = RegExp(r'(^\.)|(\.\.)|[\\/:]');

const Set<String> _allowedCacheBuckets = <String>{
  'memory',
  'data',
  'image',
  'state',
  'video',
};

const Set<String> _allowedCachePriorities = <String>{'low', 'normal', 'high'};

const Set<String> _blockedStateSegments = <String>{
  'authorization',
  'credential',
  'idtoken',
  'password',
  'refreshtoken',
  'secret',
  'token',
};
