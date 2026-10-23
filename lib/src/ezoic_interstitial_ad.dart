import 'dart:async';

import 'package:flutter/services.dart';

/// Error delivered to [EzoicInterstitialAd.onFailedToShow] and thrown by
/// [EzoicInterstitialAd.show] when presentation fails.
class EzoicInterstitialAdError {
  final String message;

  /// Native `EzoicError` code for the show failure.
  final int code;
  const EzoicInterstitialAdError(this.message, this.code);
}

/// An interstitial ad. Use [load] to fetch an ad ahead of time, then call
/// [show] to present it full-screen at a natural transition point. Interstitials
/// carry no reward.
///
/// ```dart
/// final ad = await EzoicInterstitialAd.load('12345');
/// ad.onDismissed = () => print('closed');
/// await ad.show();
/// ```
///
/// Mirrors the native `EzoicInterstitialAd` load/show lifecycle on both
/// platforms. Interstitial ads are single-use — load a new one for the next
/// opportunity.
class EzoicInterstitialAd {
  /// The Ezoic ad unit identifier. Crosses the bridge as a string and is
  /// coerced to a native `Int`.
  final String adUnitIdentifier;

  /// Called when the interstitial ad was presented full-screen.
  void Function()? onShown;

  /// Called when the interstitial ad failed to present.
  void Function(EzoicInterstitialAdError error)? onFailedToShow;

  /// Called when the interstitial ad recorded an impression.
  void Function()? onImpression;

  /// Called when the interstitial ad was clicked.
  void Function()? onClicked;

  /// Called when the interstitial ad was dismissed and the full-screen content
  /// closed.
  void Function()? onDismissed;

  static const MethodChannel _channel =
      MethodChannel('com.ezoic/ezoic_flutter_sdk');

  late final MethodChannel _eventChannel;
  bool _spent = false;
  bool _destroyed = false;
  bool _released = false;

  EzoicInterstitialAd._(this.adUnitIdentifier) {
    _eventChannel =
        MethodChannel('com.ezoic/ezoic_interstitial_ad_$adUnitIdentifier');
    _eventChannel.setMethodCallHandler(_handleEvent);
  }

  /// Loads an interstitial ad for the given Ezoic ad unit identifier. Resolves
  /// with a ready-to-show [EzoicInterstitialAd], or throws a
  /// [PlatformException] if no ad could be loaded.
  static Future<EzoicInterstitialAd> load(String adUnitIdentifier) async {
    // The instance (and its event-channel handler) is only created after the
    // native load succeeds, so a rejected load can never disturb the handler
    // of an already-loaded ad sharing the same ad unit id.
    await _channel.invokeMethod<void>(
      'loadInterstitialAd',
      {'adUnitIdentifier': adUnitIdentifier},
    );
    return EzoicInterstitialAd._(adUnitIdentifier);
  }

  /// Presents the interstitial ad full-screen. Resolves when the ad is
  /// dismissed, or throws an [EzoicInterstitialAdError] if the ad was not ready
  /// or failed to present.
  Future<void> show() async {
    try {
      await _channel.invokeMethod<void>(
        'showInterstitialAd',
        {'adUnitIdentifier': adUnitIdentifier},
      );
      _spent = true;
    } on PlatformException catch (e) {
      throw EzoicInterstitialAdError(
        e.message ?? 'Unknown error',
        _parseCode(e.details),
      );
    }
  }

  /// Releases the ad: drops the event handler and, if the ad was loaded but
  /// never shown, discards the native ad so a new one can be loaded for this
  /// unit. Safe to call multiple times.
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    final wasSpent = _spent;
    _release();
    if (!wasSpent) {
      unawaited(_channel.invokeMethod<void>(
        'destroyInterstitialAd',
        {'adUnitIdentifier': adUnitIdentifier},
      ).catchError((Object _) {}));
    }
  }

  // Event channels are named per ad unit, so a later instance for the same
  // unit owns the handler once this one has released it.
  void _release() {
    if (_released) return;
    _released = true;
    _eventChannel.setMethodCallHandler(null);
  }

  Future<dynamic> _handleEvent(MethodCall call) async {
    switch (call.method) {
      case 'onShown':
        onShown?.call();
        break;
      case 'onFailedToShow':
        final args = (call.arguments as Map).cast<String, dynamic>();
        onFailedToShow?.call(EzoicInterstitialAdError(
          args['message'] as String? ?? 'Unknown error',
          (args['code'] as num?)?.toInt() ?? 0,
        ));
        // Failure to show is terminal — the native ad is single-use.
        _spent = true;
        _release();
        break;
      case 'onImpression':
        onImpression?.call();
        break;
      case 'onClicked':
        onClicked?.call();
        break;
      case 'onDismissed':
        onDismissed?.call();
        // Dismissal is terminal — the native ad is single-use.
        _spent = true;
        _release();
        break;
    }
  }

  static int _parseCode(dynamic details) {
    if (details is int) return details;
    if (details is num) return details.toInt();
    if (details is String) return int.tryParse(details) ?? 0;
    return 0;
  }
}
