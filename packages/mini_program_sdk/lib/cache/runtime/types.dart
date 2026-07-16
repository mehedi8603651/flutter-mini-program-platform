part of '../runtime_cache.dart';

typedef MiniProgramCacheClock = DateTime Function();

enum MiniProgramCacheBucket { memory, data, image, video, session, state }

enum MiniProgramCacheStorage {
  disabled,
  memory,
  persistent,
  securePersistent,
  temporary,
}

enum MiniProgramCachePriority { low, normal, high, hostPinned }
