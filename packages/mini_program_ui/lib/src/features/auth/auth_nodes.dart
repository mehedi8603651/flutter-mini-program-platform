import '../../core/mp_node.dart';

MpNode buildAuthBuilderNode({
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
