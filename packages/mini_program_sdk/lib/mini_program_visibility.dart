/// Whether a mounted mini-program surface is currently visible to the user.
///
/// A hidden mini-program remains mounted so its in-memory state and internal
/// screen stack can be resumed without reloading. The SDK uses this signal to
/// pause or release foreground-only host resources while the surface is
/// hidden.
enum MiniProgramVisibility {
  /// The mini-program is the foreground surface and may use foreground-only
  /// host capabilities under the accepted policy.
  foreground,

  /// The mini-program remains mounted but is covered by the host surface.
  hidden,
}
