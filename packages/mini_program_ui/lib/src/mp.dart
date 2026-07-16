import 'core/mp_action.dart';
import 'core/mp_node.dart';
import 'features/auth/auth_actions.dart';
import 'features/auth/auth_nodes.dart';
import 'features/backend/backend_actions.dart';
import 'features/backend/backend_nodes.dart';
import 'features/backend/search.dart';
import 'features/cache/cache_actions.dart';
import 'features/charts/chart_nodes.dart';
import 'features/collections/collection_nodes.dart';
import 'features/composition/action_actions.dart';
import 'features/content/display_nodes.dart';
import 'features/content/image_models.dart';
import 'features/content/image_nodes.dart';
import 'features/content/text_nodes.dart';
import 'features/controls/button_nodes.dart';
import 'features/controls/list_tile_nodes.dart';
import 'features/controls/selection_nodes.dart';
import 'features/data/data_actions.dart';
import 'features/feedback/feedback_actions.dart';
import 'features/forms/form_models.dart';
import 'features/forms/form_nodes.dart';
import 'features/layout/layout_nodes.dart';
import 'features/lazy/lazy_nodes.dart';
import 'features/lifecycle/lifecycle_nodes.dart';
import 'features/lifecycle/timer_nodes.dart';
import 'features/location/location_actions.dart';
import 'features/math/math_actions.dart';
import 'features/navigation/navigation_actions.dart';
import 'features/navigation/router_actions.dart';
import 'features/skeleton/skeleton_nodes.dart';
import 'features/state/state_actions.dart';
import 'features/theme/theme_nodes.dart';

export 'features/auth/auth_actions.dart' show MpAuthActions;
export 'features/backend/backend_actions.dart' show MpBackendActions;
export 'features/backend/search.dart' show MpSearch;
export 'features/cache/cache_actions.dart'
    show MpCacheActions, MpCacheBucketActions;
export 'features/composition/action_actions.dart' show MpActionActions;
export 'features/data/data_actions.dart' show MpDataActions;
export 'features/forms/form_models.dart' show MpOption;
export 'features/lifecycle/timer_nodes.dart' show MpTimer;
export 'features/location/location_actions.dart' show MpLocationActions;
export 'features/math/math_actions.dart' show MpMathActions;
export 'features/navigation/navigation_actions.dart' show MpNavigationActions;
export 'features/navigation/router_actions.dart' show MpRouterActions;
export 'features/state/state_actions.dart' show MpStateActions;

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

  /// Safe, offline mathematical actions.
  static const math = MpMathActions();

  /// Artifact-local JSON data actions.
  static const data = MpDataActions();

  /// Host-controlled one-time location actions.
  static const location = MpLocationActions();

  /// Lifecycle-owned timer nodes.
  static const timer = MpTimer();

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
      buildColumnNode(children: children);

  /// Creates a horizontal layout.
  static MpNode row({required List<MpNode> children}) =>
      buildRowNode(children: children);

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
  static MpNode sizedBox({num? width, num? height}) =>
      buildSizedBoxNode(width: width, height: height);

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
    String direction = 'vertical',
    num? height,
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
    direction: direction,
    height: height,
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
    String direction = 'vertical',
    num? height,
  }) => buildRepeatNode(
    source: source,
    itemTemplate: itemTemplate,
    empty: empty,
    separator: separator,
    spacing: spacing,
    limit: limit,
    direction: direction,
    height: height,
  );

  /// Alias for [repeat].
  static MpNode forEach({
    required String source,
    required MpNode itemTemplate,
    MpNode? empty,
    MpNode? separator,
    num spacing = 0,
    int limit = 100,
    String direction = 'vertical',
    num? height,
  }) => repeat(
    source: source,
    itemTemplate: itemTemplate,
    empty: empty,
    separator: separator,
    spacing: spacing,
    limit: limit,
    direction: direction,
    height: height,
  );

  /// Creates a state-controlled local search field.
  static MpNode searchField({
    required String stateKey,
    String label = 'Search',
    String? hint,
    String initialValue = '',
    int maxLength = 256,
    Duration debounce = const Duration(milliseconds: 300),
    MpAction? onChanged,
    MpAction? onSubmitted,
    bool showClearButton = true,
  }) => buildSearchFieldNode(
    stateKey: stateKey,
    label: label,
    hint: hint,
    initialValue: initialValue,
    maxLength: maxLength,
    debounce: debounce,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    showClearButton: showClearButton,
  );

  /// Creates a single-series ordinal line chart.
  static MpNode lineChart({
    required String source,
    required String valueField,
    String? labelField,
    num height = 220,
    num? minY,
    num? maxY,
    String unit = '',
    String color = '#F4C430',
    num strokeWidth = 3,
    bool curved = true,
    bool showPoints = true,
    bool showGrid = true,
    bool showArea = true,
    int maxPoints = 200,
    String? semanticLabel,
    MpNode? empty,
  }) => buildLineChartNode(
    source: source,
    valueField: valueField,
    labelField: labelField,
    height: height,
    minY: minY,
    maxY: maxY,
    unit: unit,
    color: color,
    strokeWidth: strokeWidth,
    curved: curved,
    showPoints: showPoints,
    showGrid: showGrid,
    showArea: showArea,
    maxPoints: maxPoints,
    semanticLabel: semanticLabel,
    empty: empty,
  );

  /// Creates a root pull-to-refresh viewport.
  static MpNode refreshIndicator({
    required MpAction action,
    required MpNode child,
    String? semanticsLabel,
  }) => buildRefreshIndicatorNode(
    action: action,
    child: child,
    semanticsLabel: semanticsLabel,
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
  static MpNode card({required MpNode child}) => buildCardNode(child: child);

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
  }) => buildTextInputNode(
    name: name,
    label: label,
    hint: hint,
    initialValue: initialValue,
    required: required,
    minLength: minLength,
    maxLength: maxLength,
    obscureText: obscureText,
    keyboardType: keyboardType,
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
  }) => buildBackendSearchInputNode(
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
  }) => buildTextAreaNode(
    name: name,
    label: label,
    hint: hint,
    initialValue: initialValue,
    required: required,
    minLength: minLength,
    maxLength: maxLength,
    minLines: minLines,
    maxLines: maxLines,
  );

  /// Creates a select menu controlled by the SDK form state.
  static MpNode dropdown({
    required String name,
    required String label,
    required List<MpOption> options,
    String? hint,
    String? initialValue,
    bool required = false,
  }) => buildDropdownNode(
    name: name,
    label: label,
    options: options,
    hint: hint,
    initialValue: initialValue,
    required: required,
  );

  /// Creates a boolean checkbox controlled by the SDK form state.
  static MpNode checkbox({
    required String name,
    required String label,
    bool initialValue = false,
    bool requiredTrue = false,
  }) => buildCheckboxNode(
    name: name,
    label: label,
    initialValue: initialValue,
    requiredTrue: requiredTrue,
  );

  /// Creates a radio option group controlled by the SDK form state.
  static MpNode radioGroup({
    required String name,
    required String label,
    required List<MpOption> options,
    String? initialValue,
    bool required = false,
  }) => buildRadioGroupNode(
    name: name,
    label: label,
    options: options,
    initialValue: initialValue,
    required: required,
  );

  /// Creates an SDK-owned form scope.
  static MpNode form({String id = 'form', required List<MpNode> children}) =>
      buildFormNode(id: id, children: children);

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
  }) => buildFormSubmitNode(
    label: label,
    endpoint: endpoint,
    requestId: requestId,
    method: method,
    body: body,
    cacheTtlSeconds: cacheTtlSeconds,
    onSuccess: onSuccess,
    onError: onError,
  );

  /// Creates the primary button style.
  static MpNode primaryButton({
    required String label,
    required MpAction action,
  }) => buildPrimaryButtonNode(label: label, action: action);

  /// Creates the secondary button style.
  static MpNode secondaryButton({
    required String label,
    required MpAction action,
  }) => buildSecondaryButtonNode(label: label, action: action);

  /// Creates a styled command button.
  static MpNode button({
    required String label,
    required MpAction action,
    num height = 56,
    String backgroundColor = '#252525',
    String foregroundColor = '#F5F5F5',
    String borderColor = '#252525',
    num borderWidth = 0,
    num borderRadius = 8,
    num fontSize = 18,
    String fontWeight = 'medium',
  }) => buildButtonNode(
    label: label,
    action: action,
    height: height,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    borderColor: borderColor,
    borderWidth: borderWidth,
    borderRadius: borderRadius,
    fontSize: fontSize,
    fontWeight: fontWeight,
  );

  /// Creates a tappable icon command with a semantic label.
  static MpNode iconButton(
    String name, {
    required String semanticLabel,
    required MpAction action,
    num size = 48,
    num iconSize = 24,
    String color = '#9CA3AF',
    String backgroundColor = '#00000000',
    String borderColor = '#00000000',
    num borderWidth = 0,
    num borderRadius = 24,
  }) => buildIconButtonNode(
    name: name,
    semanticLabel: semanticLabel,
    action: action,
    size: size,
    iconSize: iconSize,
    color: color,
    backgroundColor: backgroundColor,
    borderColor: borderColor,
    borderWidth: borderWidth,
    borderRadius: borderRadius,
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
  }) => buildAuthBuilderNode(
    loading: loading,
    signedOut: signedOut,
    signedIn: signedIn,
    error: error,
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
  }) => buildBackendBuilderNode(
    requestId: requestId,
    endpoint: endpoint,
    method: method,
    body: body,
    cacheTtlSeconds: cacheTtlSeconds,
    forceRefresh: forceRefresh,
    loading: loading,
    error: error,
    empty: empty,
    child: child,
    itemTemplate: itemTemplate,
    itemsPath: itemsPath,
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
  }) => buildPagedBackendBuilderNode(
    requestId: requestId,
    endpoint: endpoint,
    itemTemplate: itemTemplate,
    limit: limit,
    initialCursor: initialCursor,
    cursorParam: cursorParam,
    limitParam: limitParam,
    itemsPath: itemsPath,
    nextCursorPath: nextCursorPath,
    hasMorePath: hasMorePath,
    cacheTtlSeconds: cacheTtlSeconds,
    forceRefresh: forceRefresh,
    loading: loading,
    loadingMore: loadingMore,
    error: error,
    empty: empty,
    end: end,
    loadMore: loadMore,
  );

  /// Rebuilds [child] when any declared state key changes.
  static MpNode stateBuilder({
    required List<String> keys,
    required MpNode child,
  }) => buildStateBuilderNode(keys: keys, child: child);

  /// Selects one of two node trees from a boolean literal or full binding.
  static MpNode condition({
    required Object condition,
    required MpNode whenTrue,
    MpNode? whenFalse,
  }) => buildConditionNode(
    condition: condition,
    whenTrue: whenTrue,
    whenFalse: whenFalse,
  );

  /// Runs [actions] once for each mounted instance before showing [child].
  static MpNode initialize({
    required List<MpAction> actions,
    required MpNode child,
    MpNode? loading,
    MpNode? error,
    String? statusState,
    String? errorState,
    int retry = 0,
    Duration retryDelay = const Duration(milliseconds: 300),
  }) => buildInitializeNode(
    actions: actions,
    child: child,
    loading: loading,
    error: error,
    statusState: statusState,
    errorState: errorState,
    retry: retry,
    retryDelay: retryDelay,
  );

  /// Owns a state prefix and optionally removes it when the subtree disposes.
  static MpNode stateScope({
    required String prefix,
    required MpNode child,
    bool clearOnDispose = true,
  }) => buildStateScopeNode(
    prefix: prefix,
    child: child,
    clearOnDispose: clearOnDispose,
  );

  /// Defines reusable actions for [child] and its descendants.
  static MpNode actionScope({
    required Map<String, MpAction> actions,
    required MpNode child,
  }) => buildActionScopeNode(actions: actions, child: child);

  /// Creates a toast/snackbar-style UI feedback action.
  static MpAction toast({required String message, int durationMs = 2400}) =>
      buildToastAction(message: message, durationMs: durationMs);

  /// Creates a modal confirmation/info dialog action.
  static MpAction dialog({
    String? title,
    required String message,
    String confirmLabel = 'OK',
  }) => buildDialogAction(
    title: title,
    message: message,
    confirmLabel: confirmLabel,
  );
}
