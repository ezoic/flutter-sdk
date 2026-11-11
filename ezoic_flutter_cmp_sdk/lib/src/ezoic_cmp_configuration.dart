/// Options for [EzoicCmp.initialize].
///
/// Field names and defaults mirror the native `EzoicCmpConfiguration` on iOS
/// and Android. Ignored when `EzoicAds` (package `ezoic_flutter_sdk`) runs the
/// CMP, which takes the same switches from its own configuration.
class EzoicCmpConfiguration {
  /// Run the built-in CMP: the TCF dialog in GDPR regions and the notice and
  /// "Do Not Sell" choice in covered US states. Defaults to `true`. Set to
  /// `false` if your app runs another CMP (UMP, OneTrust, ...).
  final bool cmpEnabled;

  /// `false` means the app manages consent itself: the CMP then never
  /// presents, or writes `IABTCF_*` / `IABGPP_*` keys. Defaults to `true`.
  final bool autoReadConsent;

  /// Write the CMP's debug and info lines to the platform log (logcat tag
  /// `EzoicCmp`, iOS subsystem `com.ezoic.cmp.sdk`). Defaults to `false`.
  final bool debugEnabled;

  /// Wrapper-only: right after [EzoicCmp.initialize], present the consent
  /// dialog once if it is required (see [EzoicCmp.presentConsentIfRequired]).
  /// Defaults to `true`. Set to `false` to choose the timing yourself or to
  /// receive the outcome.
  final bool autoPresentConsent;

  const EzoicCmpConfiguration({
    this.cmpEnabled = true,
    this.autoReadConsent = true,
    this.debugEnabled = false,
    this.autoPresentConsent = true,
  });

  /// Serializes this configuration for transport across the method channel.
  Map<String, Object> toMap() => {
        'cmpEnabled': cmpEnabled,
        'autoReadConsent': autoReadConsent,
        'debugEnabled': debugEnabled,
        'autoPresentConsent': autoPresentConsent,
      };
}
