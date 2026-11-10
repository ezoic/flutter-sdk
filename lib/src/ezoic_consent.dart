export 'package:ezoic_flutter_cmp_sdk/ezoic_flutter_cmp_sdk.dart'
    show
        AlreadyDecided,
        AlreadyPresenting,
        Decided,
        Dismissed,
        EzoicConsentDecision,
        EzoicConsentOutcome,
        Failed,
        NotRequired;

/// Error codes reported by the native Ezoic Ads SDK that apps may want to
/// handle explicitly.
class EzoicErrorCode {
  EzoicErrorCode._();

  /// An ad load failed because GDPR applies and the user has not made a
  /// consent choice yet (the built-in consent dialog was not shown, or was
  /// dismissed). Reported as `code` on ad errors such as `EzoicBannerError`.
  static const int consentRequired = 5001;
}
