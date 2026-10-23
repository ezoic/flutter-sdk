import 'dart:async';

import 'package:flutter/services.dart';

/// A reward earned by the user for completing a rewarded ad.
///
/// The values mirror the reward configured on the GAM rewarded ad unit.
class EzoicReward {
  /// The reward type (e.g. "coins").
  final String type;

  /// The reward amount.
  final int amount;

  const EzoicReward(this.type, this.amount);

  /// Builds an [EzoicReward] from the native `showRewardedAd` result, or
  /// returns `null` when no reward was earned (dismissed early).
  ///
  /// Exposed for reward-marshalling tests; [EzoicRewardedAd.show] uses it.
  static EzoicReward? fromShowResult(Map<String, dynamic>? result) {
    if (result != null && result['earned'] == true) {
      return EzoicReward(
        result['type'] as String? ?? '',
        (result['amount'] as num?)?.toInt() ?? 0,
      );
    }
    return null;
  }
}

/// Error delivered to [EzoicRewardedAd.onFailedToShow] when presentation fails.
class EzoicRewardedAdError {
  final String message;

  /// Native `EzoicError` code for the show failure.
  final int code;
  const EzoicRewardedAdError(this.message, this.code);
}

/// A rewarded ad. Use [load] to fetch an ad ahead of time, then call [show] to
/// present it full-screen and grant the reward once the user finishes watching.
///
/// ```dart
/// final ad = await EzoicRewardedAd.load('12345');
/// ad.onDismissed = () => print('closed');
/// final reward = await ad.show();
/// if (reward != null) grantReward(reward.amount);
/// ```
///
/// Mirrors the native `EzoicRewardedAd` load/show lifecycle on both platforms.
/// Rewarded ads are single-use — load a new one for the next opportunity.
class EzoicRewardedAd {
  /// The Ezoic ad unit identifier. Crosses the bridge as a string and is
  /// coerced to a native `Int`.
  final String adUnitIdentifier;

  /// Called when the rewarded ad was presented full-screen.
  void Function()? onShown;

  /// Called when the rewarded ad failed to present.
  void Function(EzoicRewardedAdError error)? onFailedToShow;

  /// Called when the rewarded ad recorded an impression.
  void Function()? onImpression;

  /// Called when the rewarded ad was clicked.
  void Function()? onClicked;

  /// Called when the rewarded ad was dismissed (whether or not the reward was
  /// earned).
  void Function()? onDismissed;

  /// Called when the user earned the reward by completing the ad.
  void Function(EzoicReward reward)? onUserEarnedReward;

  static const MethodChannel _channel =
      MethodChannel('com.ezoic/ezoic_flutter_sdk');

  late final MethodChannel _eventChannel;
  bool _spent = false;
  bool _destroyed = false;
  bool _released = false;

  EzoicRewardedAd._(this.adUnitIdentifier) {
    _eventChannel =
        MethodChannel('com.ezoic/ezoic_rewarded_ad_$adUnitIdentifier');
    _eventChannel.setMethodCallHandler(_handleEvent);
  }

  /// Loads a rewarded ad for the given Ezoic ad unit identifier. Resolves with
  /// a ready-to-show [EzoicRewardedAd], or throws a [PlatformException] if no
  /// ad could be loaded.
  static Future<EzoicRewardedAd> load(String adUnitIdentifier) async {
    // The instance (and its event-channel handler) is only created after the
    // native load succeeds, so a rejected load can never disturb the handler
    // of an already-loaded ad sharing the same ad unit id.
    await _channel.invokeMethod<void>(
      'loadRewardedAd',
      {'adUnitIdentifier': adUnitIdentifier},
    );
    return EzoicRewardedAd._(adUnitIdentifier);
  }

  /// Presents the rewarded ad full-screen. Resolves with the earned
  /// [EzoicReward], or `null` if the ad was dismissed before the reward was
  /// earned. Throws a [PlatformException] if the ad was not ready or failed to
  /// present.
  Future<EzoicReward?> show({String? rewardName}) async {
    final args = <String, dynamic>{'adUnitIdentifier': adUnitIdentifier};
    if (rewardName != null) {
      args['rewardName'] = rewardName;
    }
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'showRewardedAd',
      args,
    );
    _spent = true;
    return EzoicReward.fromShowResult(result);
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
        'destroyRewardedAd',
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
        onFailedToShow?.call(EzoicRewardedAdError(
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
      case 'onUserEarnedReward':
        final args = (call.arguments as Map).cast<String, dynamic>();
        onUserEarnedReward?.call(EzoicReward(
          args['type'] as String? ?? '',
          (args['amount'] as num?)?.toInt() ?? 0,
        ));
        break;
      case 'onDismissed':
        onDismissed?.call();
        // Dismissal is terminal — the native ad is single-use.
        _spent = true;
        _release();
        break;
    }
  }
}
