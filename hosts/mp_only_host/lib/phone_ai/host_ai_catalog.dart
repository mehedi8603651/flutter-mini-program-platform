import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Explicit host-owned actions for this reference catalog. These are not
/// mini-program SDK semantics and do not give the SDK access to host screens.
class HostAiCatalog {
  HostAiCatalog({required this.titles, required this.openMiniProgram});

  static const appId = 'mp_only_host';
  final Map<String, String> titles;
  final Future<void> Function(String appId) openMiniProgram;
  final viewportKey = GlobalKey();
  final scrollController = ScrollController();
  late final buttonKeys = {for (final id in titles.keys) id: GlobalKey()};
  final _sessionId = 'host-${DateTime.now().microsecondsSinceEpoch}';
  int _revision = 1;
  bool _disposed = false;

  void invalidate() => _revision++;

  Rect? _visibleRect() {
    final context = viewportKey.currentContext;
    final box = context?.findRenderObject();
    if (context == null || box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return null;
    return (box.localToGlobal(Offset.zero) & box.size).intersect(
      Offset.zero & MediaQuery.sizeOf(context),
    );
  }

  Map<String, dynamic> observe() {
    final viewport = _disposed ? null : _visibleRect();
    final nodes = <Map<String, dynamic>>[];
    if (viewport != null && !viewport.isEmpty) {
      nodes.add({
        'id': 'catalog-title',
        'role': 'text',
        'label': 'Mini-program catalog',
        'actions': <String>[],
      });
      for (final entry in titles.entries) {
        final box = buttonKeys[entry.key]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) continue;
        final bounds = box.localToGlobal(Offset.zero) & box.size;
        // Export controls only when their whole touch target is on screen.
        if (!viewport.contains(bounds.center) ||
            bounds.top < viewport.top - 1 ||
            bounds.bottom > viewport.bottom + 1) {
          continue;
        }
        nodes.add({
          'id': entry.key,
          'role': 'button',
          'label': 'Open ${entry.value}',
          'actions': ['tap'],
        });
      }
      if (scrollController.hasClients) {
        final position = scrollController.position;
        nodes.add({
          'id': 'catalog-scroll',
          'role': 'scroll',
          'label': 'Mini-program catalog',
          'actions': [
            if (position.pixels < position.maxScrollExtent - 1) 'scrollUp',
            if (position.pixels > position.minScrollExtent + 1) 'scrollDown',
          ],
        });
      }
    }
    return {
      'appId': appId,
      'sessionId': _sessionId,
      'screenId': 'catalog',
      'revision': _revision,
      'status': nodes.isEmpty ? 'unavailable' : 'ready',
      'canGoBack': false,
      'nodes': nodes,
    };
  }

  Future<Map<String, dynamic>> dispatch(Map<String, dynamic> request) async {
    if (request['method'] == 'observe') return observe();
    if (request['method'] != 'interact' || request['request'] is! Map) {
      return {'status': 'rejected', 'code': 'invalid_request'};
    }
    final command = request['request'] as Map;
    final snapshot = observe();
    if (snapshot['status'] != 'ready') {
      return {'status': 'rejected', 'code': 'foreground_required'};
    }
    if (command['sessionId'] != _sessionId ||
        command['revision'] != _revision) {
      return {'status': 'rejected', 'code': 'stale_view'};
    }
    final target = (snapshot['nodes'] as List).cast<Map>().where(
      (node) => node['id'] == command['targetId'],
    );
    if (target.length != 1 ||
        !(target.single['actions'] as List).contains(command['action'])) {
      return {'status': 'rejected', 'code': 'target_unavailable'};
    }
    // Consume the revision before the async operation; no replay can launch a
    // second task or turn an uncertain launch into a repeated submission.
    invalidate();
    if (command['action'] == 'tap') {
      final id = command['targetId'] as String;
      try {
        await openMiniProgram(id);
        return {'status': 'completed', 'nextAppId': id};
      } on Object {
        return {'status': 'rejected', 'code': 'launch_failed'};
      }
    }
    final position = scrollController.position;
    final delta = math.max(48.0, position.viewportDimension * 0.7);
    await scrollController.animateTo(
      (position.pixels + (command['action'] == 'scrollUp' ? delta : -delta))
          .clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    return {'status': 'completed'};
  }

  void dispose() {
    _disposed = true;
    scrollController.dispose();
  }
}
