/// Standard IAB banner sizes supported by [EzoicBannerView].
///
/// [toSizeString] produces the `"WxH"` representation the native SDKs expect.
enum EzoicBannerSize {
  banner(320, 50),
  largeBanner(320, 100),
  mediumRectangle(300, 250),
  fullBanner(468, 60),
  leaderboard(728, 90);

  const EzoicBannerSize(this.width, this.height);

  /// The banner width in density-independent pixels.
  final int width;

  /// The banner height in density-independent pixels.
  final int height;

  /// Returns the `"WxH"` string (e.g. `"300x250"`) consumed by the native SDK.
  String toSizeString() => '${width}x$height';
}
