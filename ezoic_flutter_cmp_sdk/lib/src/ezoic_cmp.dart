import 'package:flutter/services.dart';

import 'ezoic_cmp_configuration.dart';
import 'ezoic_consent_outcome.dart';

/// The built-in Ezoic CMP for Ezoic publishers whose app doesn't use Ezoic
/// ads. Wraps the native `EzoicCmp` on each platform over a [MethodChannel].
///
/// Apps that use `EzoicAds` (package `ezoic_flutter_sdk`) call its consent
/// methods instead; the names and outcomes are the same. Use one entry point:
/// if both are initialized, in either order, `EzoicAds` takes over the same
/// CMP and its stored decision.
///
/// Whether GDPR applies comes from the publisher's Ezoic settings for the
/// [initialize] domain. A domain that isn't an Ezoic publisher's is refused:
/// the presents return `Failed(1001, ...)`, nothing is written, and
/// [isConsentRequired] / [isPrivacyOptionsRequired] stay `null`.
class EzoicCmp {
  EzoicCmp._();

  static const MethodChannel _channel =
      MethodChannel('com.ezoic/ezoic_flutter_cmp_sdk');

  /// Starts the CMP for [domain], your domain as configured in Ezoic.
  ///
  /// Resolves at once; the publisher settings load in the background, and a
  /// [presentConsentIfRequired] meanwhile waits for them. Later calls, and
  /// calls after `EzoicAds.initialize`, are ignored by the native CMP (so a
  /// hot restart is harmless). Throws a [PlatformException] if [domain] is
  /// empty.
  static Future<void> initialize(String domain,
      [EzoicCmpConfiguration configuration =
          const EzoicCmpConfiguration()]) async {
    await _channel.invokeMethod<void>(
        'initialize', {'domain': domain, ...configuration.toMap()});
  }

  /// Presents the consent dialog if GDPR applies and no valid decision is
  /// stored. Returns [NotRequired] outside GDPR regions, including covered US
  /// states, where the CMP shows its US notice on its own.
  ///
  /// [initialize] calls this once for you unless
  /// [EzoicCmpConfiguration.autoPresentConsent] is `false`. Calling it again
  /// is harmless: you get [AlreadyPresenting] while a dialog is in flight and
  /// [AlreadyDecided] once a decision is stored.
  ///
  /// Never throws: every result is an [EzoicConsentOutcome]. "No foreground
  /// Activity / view controller" and channel errors become `Failed(-1, ...)`.
  static Future<EzoicConsentOutcome> presentConsentIfRequired() =>
      _presentConsent('presentConsentIfRequired');

  /// The "Privacy settings" entry point; show it while
  /// [isPrivacyOptionsRequired] is `true`.
  ///
  /// In a GDPR region it re-opens the consent dialog with the user's stored
  /// choices. In a covered US state it opens the US privacy settings:
  /// `Decided(acceptAll)` when saved not opted out, `Decided(rejectAll)` when
  /// saved opted out, [Dismissed] when closed without saving. Returns
  /// [NotRequired] elsewhere, when the CMP is off, when another CMP is
  /// present, or when the app manages consent. Never throws.
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

  /// Whether GDPR applies to this user and the CMP handles consent.
  ///
  /// `false` outside GDPR regions, when the CMP is off, when another CMP
  /// wrote `IABTCF_CmpSdkID`, or when the app manages consent. `null` before
  /// [initialize], while the settings load, or when none could be loaded
  /// (refused domain, blocked country, offline with no cached settings).
  static Future<bool?> isConsentRequired() {
    return _channel.invokeMethod<bool>('isConsentRequired');
  }

  /// Whether to show a "Privacy choices" entry point that calls
  /// [presentConsentSettings]: `true` in a GDPR region or a covered US state
  /// while the CMP handles consent, `false` otherwise, and `null` while
  /// unknown (before [initialize], while the settings or the US-state
  /// configuration load, or when the settings couldn't be loaded).
  static Future<bool?> isPrivacyOptionsRequired() {
    return _channel.invokeMethod<bool>('isPrivacyOptionsRequired');
  }

  /// Deletes the decision the CMP stored so the dialog is shown again. The
  /// US-state choice is forgotten too, and the US notice shows again at the
  /// next launch. Keys written by another CMP or by the app are left alone.
  static Future<void> resetConsent() async {
    await _channel.invokeMethod<void>('resetConsent');
  }
}
