import 'package:flutter/services.dart';

import 'ezoic_configuration.dart';

/// Pageview identifiers returned by a successful pageview tracking request.
class EzoicPageview {
  const EzoicPageview({required this.pageviewId, required this.visitorId});

  final String pageviewId;
  final String? visitorId;

  static EzoicPageview? fromMap(Object? value) {
    if (value is! Map) return null;
    final pageviewId = value['pageviewId'];
    if (pageviewId is! String || pageviewId.isEmpty) return null;
    final visitorId = value['visitorId'];
    return EzoicPageview(
      pageviewId: pageviewId,
      visitorId: visitorId is String ? visitorId : null,
    );
  }
}

/// Imperative entry point for the Ezoic Ads SDK.
///
/// Wraps the native `EzoicAds` singleton on each platform over a
/// [MethodChannel].
class EzoicAds {
  EzoicAds._();

  static const MethodChannel _channel = MethodChannel(
    'com.ezoic/ezoic_flutter_sdk',
  );

  /// Initializes the SDK with the given [configuration].
  ///
  /// Resolves once the native SDK reports initialization success and rejects
  /// (throws a [PlatformException]) on failure.
  static Future<void> initialize(EzoicConfiguration configuration) async {
    await _channel.invokeMethod<void>('initialize', configuration.toMap());
  }

  /// Sets GDPR consent. When [applies] is `true`, [consentString] should carry
  /// the IAB TCF consent string.
  static Future<void> setGDPRConsent(
    bool applies, [
    String? consentString,
  ]) async {
    await _channel.invokeMethod<void>('setGDPRConsent', {
      'applies': applies,
      'consentString': consentString,
    });
  }

  /// Sets GPP consent using the IAB GPP [gppString] and applicable
  /// [sectionIds].
  static Future<void> setGPPConsent([
    String? gppString,
    String? sectionIds,
  ]) async {
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

  /// Pageview id from the most recent successful pageview request.
  ///
  /// Returns `null` before the first successful pageview. Read on the main UI
  /// isolate, matching the native SDK contract.
  static Future<String?> get pageviewId async {
    return _channel.invokeMethod<String>('getPageviewId');
  }

  /// Visitor id currently held by the SDK.
  ///
  /// The native SDKs keep this in memory for the current SDK process/session
  /// and reuse it across pageviews. It is not persisted across app launches.
  static Future<String?> get visitorId async {
    return _channel.invokeMethod<String>('getVisitorId');
  }

  /// Tracks a pageview and returns the identifiers produced by the request.
  ///
  /// Failed requests preserve the native SDK's last good identifiers and
  /// resolve to `null`.
  static Future<EzoicPageview?> trackPageviewWithIds() async {
    final result = await _channel.invokeMethod<Object?>('trackPageviewWithIds');
    return EzoicPageview.fromMap(result);
  }
}
