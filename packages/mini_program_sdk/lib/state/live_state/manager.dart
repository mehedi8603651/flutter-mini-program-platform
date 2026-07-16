part of '../mp_state.dart';

/// Typed facade around [MpStore] owned by a mini-program host instance.
class MpStateManager {
  /// Creates a state manager backed by [store] or a new [MpStore].
  MpStateManager({
    MpStore? store,
    MiniProgramLiveStatePolicy policy = const MiniProgramLiveStatePolicy(),
  }) : store = store ?? MpStore(policy: policy);

  /// Backing store for advanced host-side inspection and tests.
  final MpStore store;

  MiniProgramLiveStatePolicy get policy => store.policy;

  void updatePolicy(MiniProgramLiveStatePolicy policy) =>
      store.updatePolicy(policy);

  /// Creates or replaces [key] with [value].
  void put(String key, Object? value) => store.put(key, value);

  /// Reads [key] and casts it to [T] when possible.
  T? get<T>(String key) => store.get<T>(key);

  /// Whether [key] currently exists, including null values.
  bool contains(String key) => store.contains(key);

  /// Replaces [key] with [value].
  void set(String key, Object? value) => store.set(key, value);

  /// Removes [key] if present.
  void remove(String key) => store.remove(key);

  /// Clears all memory state for this mini-program instance.
  void clear() => store.clear();

  /// Applies synchronous state writes atomically with one watcher update.
  void batchUpdates(void Function() updates) => store.batchUpdates(updates);

  /// Watches [key] for related changes.
  ValueListenable<Object?> watch(String key) => store.watch(key);

  /// Binding data exposed under `{{state.*}}`.
  Map<String, dynamic> toBindingData() => store.toBindingData();

  /// Releases state resources.
  void dispose() => store.dispose();
}
