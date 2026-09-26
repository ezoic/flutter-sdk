/// Configuration passed to [EzoicAds.initialize].
///
/// Field names and defaults mirror the native `EzoicConfiguration` on both
/// iOS and Android so the serialized map crosses the platform channel verbatim.
class EzoicConfiguration {
  /// The publisher domain registered with Ezoic (e.g. `example.com`).
  final String domain;

  /// Automatically read consent from an installed CMP. Defaults to `true`.
  final bool autoReadConsent;

  /// Whether the user is subject to COPPA. Defaults to `false`.
  final bool subjectToCOPPA;

  /// Request App Tracking Transparency before serving ads.
  ///
  /// iOS-only; this is a no-op on Android. Defaults to `true`.
  final bool requestATTBeforeAds;

  /// Enable verbose SDK logging. Defaults to `false`.
  final bool debugEnabled;

  /// Enable test mode (serves test ads). Defaults to `false`.
  final bool testMode;

  /// Let the native SDK record a pageview on its own for every host screen
  /// (Activity / view controller) it sees. Defaults to `true`.
  ///
  /// In Flutter the whole app is usually one host screen, so label each route
  /// with [EzoicAds.trackPageview]; set this to `false` when you label every
  /// screen yourself.
  final bool autoTrackPageviews;

  /// Enable the native SDK's built-in IAB TCF 2.4 consent dialog for users in
  /// GDPR regions. Defaults to `true`. Set to `false` if your app runs another
  /// CMP (UMP, OneTrust, ...).
  final bool cmpEnabled;

  /// Wrapper-only: after [EzoicAds.initialize] succeeds, present the consent
  /// dialog once if it is required (see [EzoicAds.presentConsentIfRequired]).
  /// Defaults to `true`. Set to `false` to choose the timing yourself or to
  /// receive the outcome.
  final bool autoPresentConsent;

  const EzoicConfiguration({
    required this.domain,
    this.autoReadConsent = true,
    this.subjectToCOPPA = false,
    this.requestATTBeforeAds = true,
    this.debugEnabled = false,
    this.testMode = false,
    this.autoTrackPageviews = true,
    this.cmpEnabled = true,
    this.autoPresentConsent = true,
  });

  /// Serializes this configuration for transport across the method channel.
  Map<String, dynamic> toMap() => {
        'domain': domain,
        'autoReadConsent': autoReadConsent,
        'subjectToCOPPA': subjectToCOPPA,
        'requestATTBeforeAds': requestATTBeforeAds,
        'debugEnabled': debugEnabled,
        'testMode': testMode,
        'autoTrackPageviews': autoTrackPageviews,
        'cmpEnabled': cmpEnabled,
        'autoPresentConsent': autoPresentConsent,
      };
}
