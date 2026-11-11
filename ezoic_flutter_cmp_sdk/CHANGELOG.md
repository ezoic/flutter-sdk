## 1.22.0 (unreleased)

* First release. Wraps the native Ezoic CMP 1.22.0 (`com.ezoic.sdk:ezoic-cmp-sdk:1.22.0` on Android; `EzoicCmpSDK` from [ezoic-swift-sdk-dist](https://github.com/ezoic/ezoic-swift-sdk-dist) on iOS, through Swift Package Manager or the vendored CocoaPods XCFramework).
* `EzoicCmp`: `initialize`, `presentConsentIfRequired`, `presentConsentSettings`, `isConsentRequired`, `isPrivacyOptionsRequired` and `resetConsent`, with the same outcomes as `EzoicAds` in `ezoic_flutter_sdk`.
* The consent outcome types (`EzoicConsentOutcome` and its cases, `EzoicConsentDecision`) live here; `ezoic_flutter_sdk` re-exports them.
