import 'package:flutter/services.dart';

import 'ezoic_configuration.dart';

/// Imperative entry point for the Ezoic Ads SDK.
///
/// Wraps the native `EzoicAds` singleton on each platform over a
/// [MethodChannel].
class EzoicAds {
  EzoicAds._();

  static const MethodChannel _channel =
      MethodChannel('com.ezoic/ezoic_flutter_sdk');

  /// Initializes the SDK with the given [configuration].
  ///
  /// Resolves once the native SDK reports initialization success and rejects
  /// (throws a [PlatformException]) on failure.
  static Future<void> initialize(EzoicConfiguration configuration) async {
    await _channel.invokeMethod<void>('initialize', configuration.toMap());
  }

  /// Sets GDPR consent. When [applies] is `true`, [consentString] should carry
  /// the IAB TCF consent string.
  static Future<void> setGDPRConsent(bool applies,
      [String? consentString]) async {
    await _channel.invokeMethod<void>('setGDPRConsent', {
      'applies': applies,
      'consentString': consentString,
    });
  }

  /// Sets GPP consent using the IAB GPP [gppString] and applicable
  /// [sectionIds].
  static Future<void> setGPPConsent(
      [String? gppString, String? sectionIds]) async {
    await _channel.invokeMethod<void>('setGPPConsent', {
      'gppString': gppString,
      'sectionIds': sectionIds,
    });
  }

  /// Marks whether the user is subject to COPPA.
  static Future<void> setSubjectToCOPPA(bool value) async {
    await _channel.invokeMethod<void>('setSubjectToCOPPA', {'value': value});
  }

  /// Tracks a pageview. Resolves to whether the native SDK accepted it.
  static Future<bool> trackPageview() async {
    final result = await _channel.invokeMethod<bool>('trackPageview');
    return result ?? false;
  }
}
