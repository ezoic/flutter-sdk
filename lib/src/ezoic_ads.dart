import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Native `EzoicError.alreadyInitialized`, delivered in
  /// [PlatformException.details].
  static const int _alreadyInitialized = 1002;

  static Future<void>? _initialization;

  /// Initializes the SDK with the given [configuration].
  ///
  /// Resolves once the native SDK reports initialization success and rejects
  /// (throws a [PlatformException]) on failure.
  ///
  /// Safe to call more than once: concurrent and later calls share the first
  /// call's result (the first [configuration] wins), a hot restart resolves
  /// even though the native SDK is already initialized, and a failed call is
  /// retried by the next one.
  static Future<void> initialize(EzoicConfiguration configuration) {
    final pending = _initialization;
    if (pending != null) return pending;
    final future = _initializeNative(configuration);
    _initialization = future;
    future.then((_) {}, onError: (Object _) {
      if (identical(_initialization, future)) _initialization = null;
    });
    return future;
  }

  static Future<void> _initializeNative(
      EzoicConfiguration configuration) async {
    try {
      await _channel.invokeMethod<void>('initialize', configuration.toMap());
    } on PlatformException catch (e) {
      if (e.details != _alreadyInitialized) rethrow;
      // The native SDK outlives a hot restart, so it is already up; only the
      // consent prompt the native success path runs is owed.
      if (configuration.autoPresentConsent) {
        unawaited(presentConsentIfRequired());
      }
    }
  }

  /// Forgets a completed or in-flight [initialize] so the next call reaches
  /// the platform again.
  @visibleForTesting
  static void resetInitializationForTesting() {
    _initialization = null;
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

  /// Describes your app's content to bidders (OpenRTB `app.content`),
  /// replacing any previous value; every later auction carries it.
  ///
  /// [language] is an ISO-639-1 two-letter code (`'en'`, `'de'`; case is
  /// ignored); other values are dropped with a native warning. [genre] is free
  /// text (e.g. `'News'`). Null or blank fields are omitted; calling it with
  /// neither clears it. Safe to call before [initialize].
  static Future<void> setAppContent({String? language, String? genre}) async {
    await _channel.invokeMethod<void>('setAppContent', {
      'language': language,
      'genre': genre,
    });
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
  /// decision is stored. Returns [NotRequired] outside GDPR regions, including
  /// covered US states, where the native SDK shows its US privacy notice on
  /// its own (ads never wait for it).
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

  /// The "Privacy settings" entry point; show it while
  /// [isPrivacyOptionsRequired] is `true`.
  ///
  /// In a GDPR region it re-opens the consent dialog with the user's stored
  /// choices so they can change them (TCF policy requires a persistent entry
  /// point that calls this). In a covered US state it opens the US privacy
  /// settings: `Decided(acceptAll)` when saved not opted out,
  /// `Decided(rejectAll)` when saved opted out, [Dismissed] when closed
  /// without saving. Resolves to [NotRequired] elsewhere, when
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

  /// Whether to show a "Privacy choices" entry point that calls
  /// [presentConsentSettings]: `true` in a GDPR region or a covered US state
  /// while the built-in CMP handles consent, `false` otherwise (elsewhere,
  /// `cmpEnabled` off, another CMP, or consent managed by the app). `null`
  /// while unknown: until the init request and the US-state configuration
  /// have loaded, or when the server sent no consent information.
  static Future<bool?> isPrivacyOptionsRequired() {
    return _channel.invokeMethod<bool>('isPrivacyOptionsRequired');
  }

  /// Deletes the decision stored by the built-in CMP so the dialog is shown
  /// again (ads re-gate until the user decides). The US-state choice is
  /// forgotten too, and the US notice shows again at the next launch. Keys
  /// written by another CMP are left alone.
  static Future<void> resetConsent() async {
    await _channel.invokeMethod<void>('resetConsent');
  }
}
