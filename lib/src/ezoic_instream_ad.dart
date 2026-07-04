import 'package:flutter/services.dart';

/// Error thrown by [EzoicInstreamAd.load] when the native load fails.
class EzoicInstreamAdError {
  final String message;
  final int code;
  const EzoicInstreamAdError(this.message, this.code);
}

/// A view-less controller over the native instream video unit.
///
/// Instream video runs inside the host app's OWN video content: the host owns
/// the video player and the Google IMA SDK. This controller renders nothing —
/// its deliverable is a GAM VAST ad-tag URL the host feeds to its IMA
/// `AdsRequest`.
///
/// Unlike [EzoicInterstitialAd], instream is multi-use / prefetchable: the
/// controller lives until an explicit [destroy], and the native instance keeps
/// its last-delivered tag state across [load] cycles so a prefetch does not
/// invalidate an ad still playing.
///
/// ```dart
/// final instream = EzoicInstreamAd('12345');
/// final tagUrl = await instream.load(contentUrl: playingVideoUrl);
/// // Feed tagUrl to the host IMA AdsRequest.
///
/// // On an IMA ad error, walk the floor waterfall:
/// final next = await instream.getNextAdTagUrl(); // null = exhausted
///
/// // When IMA reports the ad STARTED:
/// await instream.reportImpression();
///
/// await instream.destroy();
/// ```
class EzoicInstreamAd {
  /// The Ezoic ad unit identifier. Crosses the bridge as a string and is
  /// coerced to a native `Int`.
  final String adUnitIdentifier;

  static const MethodChannel _channel =
      MethodChannel('com.ezoic/ezoic_flutter_sdk');

  EzoicInstreamAd(this.adUnitIdentifier);

  /// Loads the instream config and resolves with the GAM VAST ad-tag URL, or
  /// throws an [EzoicInstreamAdError] when no tag could be produced (SDK not
  /// initialized, no config, or no fill).
  ///
  /// [contentUrl] — the URL of the video the host is playing — is folded into
  /// the tag as `url`/`description_url` when non-null.
  Future<String> load({String? contentUrl}) async {
    try {
      final tagUrl = await _channel.invokeMethod<String>(
        'loadInstreamAd',
        {'adUnitIdentifier': adUnitIdentifier, 'contentUrl': contentUrl},
      );
      return tagUrl ?? '';
    } on PlatformException catch (e) {
      throw EzoicInstreamAdError(
        e.message ?? 'Unknown error',
        _parseCode(e.details),
      );
    }
  }

  /// Pops the current head off the floor waterfall and returns the tag rebuilt
  /// with the next `eb_br` hash. Returns null when the waterfall is exhausted
  /// (or no tag has loaded). The host calls this on an IMA ad error.
  Future<String?> getNextAdTagUrl() {
    return _channel.invokeMethod<String>(
      'getInstreamNextAdTagUrl',
      {'adUnitIdentifier': adUnitIdentifier},
    );
  }

  /// Fires the Ezoic impression pixel for the most recently delivered tag. The
  /// host calls this when IMA reports the ad STARTED. [revenueUsd] is the
  /// optional publisher-reported value.
  Future<void> reportImpression({double? revenueUsd}) async {
    await _channel.invokeMethod<void>(
      'reportInstreamImpression',
      {'adUnitIdentifier': adUnitIdentifier, 'revenueUsd': revenueUsd},
    );
  }

  /// Releases the native controller. Safe to call multiple times.
  Future<void> destroy() async {
    await _channel.invokeMethod<void>(
      'destroyInstreamAd',
      {'adUnitIdentifier': adUnitIdentifier},
    );
  }

  static int _parseCode(dynamic details) {
    if (details is int) return details;
    if (details is num) return details.toInt();
    if (details is String) return int.tryParse(details) ?? 0;
    return 0;
  }
}
