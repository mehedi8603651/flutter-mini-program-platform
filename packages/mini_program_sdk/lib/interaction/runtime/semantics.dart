// The bit-flag API also supports the SDK's minimum Flutter version.
// ignore_for_file: deprecated_member_use
part of '../mini_program_interaction.dart';

class _InteractionTarget {
  const _InteractionTarget(this.node, this.owner, this.actions);
  final SemanticsNode node;
  final SemanticsOwner owner;
  final List<MiniProgramInteractionAction> actions;
}

const _semanticActions = <MiniProgramInteractionAction, SemanticsAction>{
  MiniProgramInteractionAction.tap: SemanticsAction.tap,
  MiniProgramInteractionAction.enterText: SemanticsAction.setText,
  MiniProgramInteractionAction.scrollUp: SemanticsAction.scrollUp,
  MiniProgramInteractionAction.scrollDown: SemanticsAction.scrollDown,
  MiniProgramInteractionAction.scrollLeft: SemanticsAction.scrollLeft,
  MiniProgramInteractionAction.scrollRight: SemanticsAction.scrollRight,
  MiniProgramInteractionAction.increase: SemanticsAction.increase,
  MiniProgramInteractionAction.decrease: SemanticsAction.decrease,
};

MiniProgramInteractionSnapshot _capture(
  _InteractionSurfaceState surface, {
  bool renderPending = false,
}) {
  surface.targets.clear();
  surface.executions.removeWhere((e) => e.pending == 0 && !e.active);
  final status = !surface.visible
      ? 'hidden'
      : !surface.current
      ? 'blocked'
      : surface.pending || renderPending
      ? 'pending'
      : 'ready';
  final nodes = <MiniProgramInteractionNode>[];
  final signature = <Object?>[
    surface.widget.appId,
    surface.screenId,
    surface.generation,
    surface.widget.revisionToken?.call(),
    status,
    surface.canGoBack,
  ];
  var truncated = false;
  var byteCount = 0;
  var visited = 0;
  // The root semantics transform maps logical coordinates to physical pixels.
  // Compare in that same space; using MediaQuery's logical size drops controls
  // near the bottom/right on high-density screens (including modal choices).
  final view = View.of(surface.context);
  final viewport = Rect.fromLTRB(
    view.viewInsets.left,
    view.viewInsets.top,
    view.physicalSize.width - view.viewInsets.right,
    view.physicalSize.height - view.viewInsets.bottom,
  );

  void collect(
    SemanticsNode node,
    SemanticsOwner owner,
    String? parentId,
    bool inScope,
    int depth,
  ) {
    if (++visited > 10000 || depth > 100) {
      truncated = true;
      return;
    }
    final data = node.getSemanticsData();
    if (data.hasFlag(SemanticsFlag.isHidden)) return;
    final owned = inScope || node.isTagged(surface.tag);
    var nextParent = parentId;
    if (owned && !node.isMergedIntoParent) {
      var rect = node.rect;
      SemanticsNode? ancestor = node;
      while (ancestor != null) {
        if (ancestor.transform != null) {
          rect = MatrixUtils.transformRect(ancestor.transform!, rect);
        }
        ancestor = ancestor.parent;
      }
      if (!rect.overlaps(viewport)) return;
      final protected = data.hasFlag(SemanticsFlag.isObscured);
      final enabled =
          !data.hasFlag(SemanticsFlag.hasEnabledState) ||
          data.hasFlag(SemanticsFlag.isEnabled);
      final textField = data.hasFlag(SemanticsFlag.isTextField);
      final actions = <MiniProgramInteractionAction>[
        if (enabled && !protected && data.platformViewId == null)
          for (final entry in _semanticActions.entries)
            if (data.hasAction(entry.value) ||
                (entry.key == MiniProgramInteractionAction.enterText &&
                    textField &&
                    !data.hasFlag(SemanticsFlag.isReadOnly)))
              entry.key,
      ];
      final label = _clip(data.label.isEmpty ? data.tooltip : data.label);
      final value = protected ? null : _clip(data.value);
      if (data.label.length > 512 ||
          data.tooltip.length > 512 ||
          (!protected && data.value.length > 512) ||
          data.hint.length > 512) {
        truncated = true;
      }
      // These opaque local hashes detect changes even beyond displayed bounds.
      signature.addAll([
        node.id,
        data.label.hashCode,
        protected ? 0 : data.value.hashCode,
        data.actions,
        data.flags,
        rect,
        data.platformViewId,
      ]);
      if (label.isNotEmpty ||
          (value?.isNotEmpty ?? false) ||
          actions.isNotEmpty ||
          protected) {
        final id = 'n${node.id}';
        final descriptor = MiniProgramInteractionNode(
          id: id,
          parentId: parentId,
          role: protected
              ? 'protectedField'
              : textField
              ? 'textField'
              : data.platformViewId != null
              ? 'platformView'
              : data.hasFlag(SemanticsFlag.hasCheckedState)
              ? 'checkbox'
              : data.hasFlag(SemanticsFlag.hasToggledState)
              ? 'switch'
              : data.hasFlag(SemanticsFlag.isButton)
              ? 'button'
              : actions.any((a) => a.name.startsWith('scroll'))
              ? 'scrollable'
              : data.hasFlag(SemanticsFlag.isImage)
              ? 'image'
              : 'text',
          label: label,
          value: value == '' ? null : value,
          hint: data.hint.isEmpty ? null : _clip(data.hint),
          enabled: enabled,
          protected: protected,
          selected: data.hasFlag(SemanticsFlag.isSelected) ? true : null,
          checked: data.hasFlag(SemanticsFlag.hasCheckedState)
              ? data.hasFlag(SemanticsFlag.isChecked)
              : data.hasFlag(SemanticsFlag.hasToggledState)
              ? data.hasFlag(SemanticsFlag.isToggled)
              : null,
          maxLength: data.maxValueLength,
          actions: actions,
        );
        final size = utf8.encode(jsonEncode(descriptor.toJson())).length;
        if (nodes.length >= 160 || byteCount + size > 28000) {
          truncated = true;
        } else {
          byteCount += size;
          nodes.add(descriptor);
          surface.targets[id] = _InteractionTarget(node, owner, actions);
          nextParent = id;
        }
      }
      if (protected || data.platformViewId != null) return;
    }
    node.visitChildren((child) {
      collect(child, owner, nextParent, owned, depth + 1);
      return visited <= 10000;
    });
  }

  if (surface.current && !renderPending) {
    void visitOwner(PipelineOwner pipeline) {
      final owner = pipeline.semanticsOwner;
      final root = owner?.rootSemanticsNode;
      if (owner != null && root != null) collect(root, owner, null, false, 0);
      pipeline.visitChildren(visitOwner);
    }

    visitOwner(RendererBinding.instance.rootPipelineOwner);
  }
  final fingerprint = Object.hashAll(signature);
  if (surface.fingerprint != fingerprint) {
    surface.fingerprint = fingerprint;
    surface.revision++;
  }
  return MiniProgramInteractionSnapshot(
    appId: surface.widget.appId,
    sessionId: surface.sessionId,
    screenId: surface.screenId,
    revision: surface.revision,
    status: status == 'ready' && nodes.isEmpty ? 'unavailable' : status,
    nodes: nodes,
    canGoBack: surface.canGoBack,
    truncated: truncated,
  );
}

String _clip(String value) =>
    value.length <= 512 ? value : '${value.substring(0, 511)}…';
