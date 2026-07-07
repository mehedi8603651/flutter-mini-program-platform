part of '../mp_screen_renderer.dart';

final RegExp _unsafeCacheKeyPattern = RegExp(r'(^\.)|(\.\.)|[\\/:]');

const Set<String> _allowedMiniProgramCacheBuckets = <String>{
  'memory',
  'data',
  'image',
  'state',
  'video',
};

const Set<String> _allowedMiniProgramCachePriorities = <String>{
  'low',
  'normal',
  'high',
};

class _MpScreen {
  const _MpScreen({required this.screenId, required this.root});

  final String screenId;
  final _MpNode root;
}

class _MpNode {
  const _MpNode({
    required this.type,
    required this.props,
    required this.children,
  });

  final String type;
  final Map<String, dynamic> props;
  final List<_MpNode> children;
}

class _MpAction {
  const _MpAction({required this.type, required this.props});

  final String type;
  final Map<String, dynamic> props;
}

class _MpValidationState {
  int nodeCount = 0;
}
