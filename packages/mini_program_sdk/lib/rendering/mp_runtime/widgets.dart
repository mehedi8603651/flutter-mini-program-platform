part of '../mp_screen_renderer.dart';

class _MpScreenView extends StatelessWidget {
  const _MpScreenView({required this.screen});

  final _MpScreen screen;

  @override
  Widget build(BuildContext context) {
    final bindings = _MpRenderBindings(
      scope: MiniProgramSdkScope.maybeOf(context),
      screenId: screen.screenId,
    );
    if (screen.root.type == 'refreshIndicator') {
      return SafeArea(
        child: _MpRefreshViewport(node: screen.root, bindings: bindings),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: _MpNodeView(node: screen.root, bindings: bindings),
      ),
    );
  }
}

enum _MpParentKind { normal, stack }

class _MpNodeView extends StatelessWidget {
  const _MpNodeView({
    required this.node,
    required this.bindings,
    this.parentKind = _MpParentKind.normal,
  });

  final _MpNode node;
  final _MpRenderBindings bindings;
  final _MpParentKind parentKind;

  @override
  Widget build(BuildContext context) {
    return switch (node.type) {
      'column' => _MpColumn(node: node, bindings: bindings),
      'row' => _MpRow(node: node, bindings: bindings),
      'text' || 'heading' => _MpText(node: node, bindings: bindings),
      'sizedBox' => SizedBox(
        width: (node.props['width'] as num?)?.toDouble(),
        height: (node.props['height'] as num?)?.toDouble(),
      ),
      'image' => _MpImage(node: node, bindings: bindings),
      'lazy' => _MpLazySection(node: node, bindings: bindings),
      'lazyChunk' => _MpLazyChunk(node: node, bindings: bindings),
      'initialize' => _MpInitialize(node: node, bindings: bindings),
      'condition' => _MpCondition(node: node, bindings: bindings),
      'countdown' => _MpCountdown(node: node, bindings: bindings),
      'stateScope' => _MpStateScope(node: node, bindings: bindings),
      'actionScope' => _MpActionScope(node: node, bindings: bindings),
      'skeleton' => _MpSkeleton(node: node, bindings: bindings),
      'card' => _MpCard(node: node, bindings: bindings),
      'theme' => _MpTheme(node: node, bindings: bindings),
      'padding' => Padding(
        padding: _mpInsets(node.props['padding'] as Map<String, dynamic>?),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'align' => Align(
        alignment: _mpAlignment(_string(node, 'alignment')),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'center' => Center(
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'spacer' => const SizedBox.shrink(),
      'expanded' => _MpNodeView(node: node.children.single, bindings: bindings),
      'flexible' => _MpNodeView(node: node.children.single, bindings: bindings),
      'container' => _MpContainer(node: node, bindings: bindings),
      'scrollView' => _MpScrollView(node: node, bindings: bindings),
      'listView' => _MpListView(node: node, bindings: bindings),
      'repeat' => _MpRepeat(node: node, bindings: bindings),
      'lineChart' => _MpLineChart(node: node, bindings: bindings),
      'refreshIndicator' => _MpNodeView(
        node: node.children.single,
        bindings: bindings,
      ),
      'safeArea' => SafeArea(
        left: _bool(node, 'left'),
        top: _bool(node, 'top'),
        right: _bool(node, 'right'),
        bottom: _bool(node, 'bottom'),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'visibility' => _MpVisibility(node: node, bindings: bindings),
      'opacity' => Opacity(
        opacity: _double(node, 'opacity', fallback: 1),
        alwaysIncludeSemantics: _bool(node, 'alwaysIncludeSemantics'),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'aspectRatio' => AspectRatio(
        aspectRatio: _double(node, 'aspectRatio', fallback: 1),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'stack' => _MpStack(node: node, bindings: bindings),
      'positioned' =>
        parentKind == _MpParentKind.stack
            ? _MpPositioned(node: node, bindings: bindings)
            : _MpNodeView(node: node.children.single, bindings: bindings),
      'divider' => _MpDivider(node: node, bindings: bindings),
      'icon' => _MpIcon(node: node, bindings: bindings),
      'listTile' => _MpListTile(node: node, bindings: bindings),
      'chip' => _MpChip(node: node, bindings: bindings),
      'badge' => _MpBadge(node: node, bindings: bindings),
      'alert' => _MpAlert(node: node, bindings: bindings),
      'avatar' => _MpAvatar(node: node, bindings: bindings),
      'grid' => _MpGrid(node: node, bindings: bindings),
      'wrap' => _MpWrap(node: node, bindings: bindings),
      'progress' => _MpProgress(node: node, bindings: bindings),
      'emptyState' => _MpEmptyState(node: node, bindings: bindings),
      'section' => _MpSection(node: node, bindings: bindings),
      'primaryButton' => _MpButton(
        node: node,
        primary: true,
        bindings: bindings,
      ),
      'secondaryButton' => _MpButton(
        node: node,
        primary: false,
        bindings: bindings,
      ),
      'button' => _MpButton(node: node, primary: false, bindings: bindings),
      'iconButton' => _MpIconButton(node: node, bindings: bindings),
      'textInput' => _MpTextInputField(node: node, multiline: false),
      'searchInput' => _MpSearchInputField(node: node, bindings: bindings),
      'searchField' => _MpStateSearchField(node: node, bindings: bindings),
      'textArea' => _MpTextInputField(node: node, multiline: true),
      'dropdown' => _MpDropdownField(node: node),
      'checkbox' => _MpCheckboxField(node: node),
      'radioGroup' => _MpRadioGroupField(node: node),
      'form' => _MpForm(node: node, bindings: bindings),
      'formSubmit' => _MpFormSubmitButton(node: node, bindings: bindings),
      'authBuilder' => _MpAuthBuilder(node: node, bindings: bindings),
      'backendBuilder' => _MpBackendBuilder(node: node, bindings: bindings),
      'pagedBackendBuilder' => _MpPagedBackendBuilder(
        node: node,
        bindings: bindings,
      ),
      'stateBuilder' => _MpStateBuilder(node: node, bindings: bindings),
      _ => throw MiniProgramRenderException(
        message: 'Unsupported Mp node type "${node.type}".',
        details: <String, dynamic>{'nodeType': node.type},
      ),
    };
  }
}
