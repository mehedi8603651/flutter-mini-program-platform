import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

class MiniProgramPreviewWatcher {
  MiniProgramPreviewWatcher({
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  final Duration debounceDuration;

  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  Future<void> Function()? _onRebuild;
  String? _rootPath;
  bool _rebuildInProgress = false;
  bool _queuedRebuild = false;

  Future<void> start({
    required String rootPath,
    required Future<void> Function() onRebuild,
  }) async {
    await stop();
    _rootPath = p.normalize(p.absolute(rootPath));
    _onRebuild = onRebuild;

    _subscription = Directory(_rootPath!).watch(recursive: true).listen((
      event,
    ) {
      if (!isRelevantPath(rootPath: _rootPath!, path: event.path)) {
        return;
      }

      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, _scheduleRebuild);
    });
  }

  Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _onRebuild = null;
    _rootPath = null;
    _rebuildInProgress = false;
    _queuedRebuild = false;
  }

  static bool isRelevantPath({required String rootPath, required String path}) {
    final normalizedRootPath = p.normalize(p.absolute(rootPath));
    final normalizedPath = p.normalize(p.absolute(path));
    final manifestPath = p.join(normalizedRootPath, 'manifest.json');
    final mpBuildScriptPath = p.join(
      normalizedRootPath,
      'tool',
      'build_mp.dart',
    );

    if (p.equals(normalizedPath, manifestPath) ||
        p.equals(normalizedPath, mpBuildScriptPath)) {
      return true;
    }

    if (!p.isWithin(normalizedRootPath, normalizedPath)) {
      return false;
    }

    if (_isIgnoredPath(normalizedPath, rootPath: normalizedRootPath)) {
      return false;
    }

    return p.isWithin(p.join(normalizedRootPath, 'mp'), normalizedPath) ||
        p.isWithin(p.join(normalizedRootPath, 'assets'), normalizedPath);
  }

  static bool _isIgnoredPath(String path, {required String rootPath}) {
    return _pathEqualsOrIsWithin(p.join(rootPath, '.mini_program'), path) ||
        _pathEqualsOrIsWithin(p.join(rootPath, '.dart_tool'), path) ||
        _pathEqualsOrIsWithin(p.join(rootPath, 'build'), path) ||
        _pathEqualsOrIsWithin(p.join(rootPath, 'mp', '.build'), path);
  }

  static bool _pathEqualsOrIsWithin(String rootPath, String path) {
    return p.equals(rootPath, path) || p.isWithin(rootPath, path);
  }

  void _scheduleRebuild() {
    final onRebuild = _onRebuild;
    if (onRebuild == null) {
      return;
    }

    if (_rebuildInProgress) {
      _queuedRebuild = true;
      return;
    }

    unawaited(_runRebuildLoop(onRebuild));
  }

  Future<void> _runRebuildLoop(Future<void> Function() onRebuild) async {
    _rebuildInProgress = true;
    try {
      do {
        _queuedRebuild = false;
        await onRebuild();
      } while (_queuedRebuild);
    } finally {
      _rebuildInProgress = false;
    }
  }
}
