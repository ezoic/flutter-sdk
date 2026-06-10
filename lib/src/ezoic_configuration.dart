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

  const EzoicConfiguration({
    required this.domain,
    this.autoReadConsent = true,
    this.subjectToCOPPA = false,
    this.requestATTBeforeAds = true,
    this.debugEnabled = false,
    this.testMode = false,
  });

  /// Serializes this configuration for transport across the method channel.
  Map<String, dynamic> toMap() => {
        'domain': domain,
        'autoReadConsent': autoReadConsent,
        'subjectToCOPPA': subjectToCOPPA,
        'requestATTBeforeAds': requestATTBeforeAds,
        'debugEnabled': debugEnabled,
        'testMode': testMode,
      };
}
