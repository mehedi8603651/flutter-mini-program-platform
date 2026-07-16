/// Source strategy for Mp image nodes.
enum MpImageSource {
  /// Let the SDK infer network, asset, or base64 from the image source.
  auto('auto'),

  /// Load the image from an HTTP(S) URL.
  network('network'),

  /// Load the image from the host Flutter asset bundle.
  asset('asset'),

  /// Load the image from raw base64 or a data URI.
  base64('base64');

  const MpImageSource(this.wireName);

  /// Stable JSON value.
  final String wireName;
}

/// Fit behavior for Mp image nodes.
enum MpImageFit {
  /// Fill while preserving aspect ratio and cropping overflow.
  cover('cover'),

  /// Fit fully within bounds while preserving aspect ratio.
  contain('contain'),

  /// Fill bounds without preserving aspect ratio.
  fill('fill'),

  /// Fit to the available width.
  fitWidth('fitWidth'),

  /// Fit to the available height.
  fitHeight('fitHeight'),

  /// Paint at natural size.
  none('none');

  const MpImageFit(this.wireName);

  /// Stable JSON value.
  final String wireName;
}
