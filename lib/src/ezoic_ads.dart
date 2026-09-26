import 'package:flutter/services.dart';

import 'ezoic_configuration.dart';
import 'ezoic_consent.dart';

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
  ///
  /// Pass a [screen] label (e.g. the route name) when the user lands on a
  /// screen so Ezoic reports the pageview, and the ads shown on that screen,
  /// under that page. Use `/` for hierarchy (`members/profile`); spaces become
  /// `-`, punctuation is dropped, case is kept. A labelled pageview takes
  /// precedence over the native SDK's automatic pageview for the same
  /// navigation. Without a label (or with an empty one) the native SDK uses its
  /// default label for the host screen.
  static Future<bool> trackPageview([String? screen]) async {
    final result =
        await _channel.invokeMethod<bool>('trackPageview', {'screen': screen});
    return result ?? false;
  }

  /// Presents the built-in consent dialog if GDPR applies and no valid
  /// decision is stored.
  ///
  /// In GDPR regions, ad loads wait while the dialog is loading or on screen
  /// (at most 5 minutes in total), and up to 10 seconds otherwise, then fail
  /// with [EzoicErrorCode.consentRequired]. [EzoicAds.initialize] calls this
  /// once for you unless [EzoicConfiguration.autoPresentConsent] is `false`.
  /// Calling it again is harmless: you get [AlreadyPresenting] while a dialog
  /// is in flight and [AlreadyDecided] once a decision is stored. Safe to call
  /// before initialization finishes; if init fails you get a [Failed] outcome.
  ///
  /// Never throws: every result is an [EzoicConsentOutcome]. "No foreground
  /// Activity / view controller" and channel errors (e.g. the plugin is not
  /// registered) become `Failed(-1, ...)`.
  static Future<EzoicConsentOutcome> presentConsentIfRequired() =>
      _presentConsent('presentConsentIfRequired');

  /// Re-opens the consent dialog with the user's stored choices so they can
  /// change them.
  ///
  /// TCF policy requires a persistent "Privacy settings" entry point that
  /// calls this. Resolves to [NotRequired] outside GDPR regions, when
  /// [EzoicConfiguration.cmpEnabled] is `false`, when another CMP is present,
  /// or when consent is managed by the app.
  static Future<EzoicConsentOutcome> presentConsentSettings() =>
      _presentConsent('presentConsentSettings');

  static Future<EzoicConsentOutcome> _presentConsent(String method) async {
    try {
      return EzoicConsentOutcome.fromMap(
          await _channel.invokeMethod<Object?>(method));
    } on PlatformException catch (e) {
      return Failed(-1, e.message ?? e.toString());
    } on MissingPluginException catch (e) {
      return Failed(-1, e.message ?? e.toString());
    } catch (e) {
      return Failed(-1, e.toString());
    }
  }

  /// Whether GDPR applies to this user and the built-in CMP handles consent.
  ///
  /// `true` whenever GDPR applies and the built-in CMP is in charge, including
  /// after the user has decided; `false` otherwise. `null` until the init
  /// request completes, or when the server sent no consent information.
  static Future<bool?> isConsentRequired() {
    return _channel.invokeMethod<bool>('isConsentRequired');
  }

  /// Deletes the decision stored by the built-in CMP so the dialog is shown
  /// again (ads re-gate until the user decides). Keys written by another CMP
  /// are left alone.
  static Future<void> resetConsent() async {
    await _channel.invokeMethod<void>('resetConsent');
  }
}
