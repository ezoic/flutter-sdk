## 1.24.0

* Wraps the native Ezoic CMP 1.24.0 on Android (`com.ezoic.sdk:ezoic-cmp-sdk:1.24.0`) and iOS (`EzoicCmpSDK`; Swift Package Manager resolves 1.24.0+). No CMP API changes: released together with `ezoic_flutter_sdk` 1.24.0.
* The consent types the CMP and the ads SDK share moved to a new native consent core (Android `com.ezoic.sdk:ezoic-consent-core`, a dependency of `ezoic-cmp-sdk`; iOS `EzoicConsentCore`). Nothing to change in your app. iOS CocoaPods builds now also download `EzoicConsentCore-1.24.0-cocoapods.xcframework.zip` (SHA-256 pinned in `pubspec.yaml` under `ezoic.ios_sdk.sha256`, now one entry per framework), and this pod vendors it for `ezoic_flutter_sdk` too.
* Android: an app using `ezoic_flutter_sdk` may exclude the native `ezoic-cmp-sdk` (see that package's README). This package then stays in the app with its native CMP missing: release builds still pass R8, and `EzoicCmp` calls fail with a `PlatformException` instead of crashing. Using `EzoicCmp` in such an app is not supported.

## 1.22.3

* Wraps the native Ezoic CMP 1.22.3 on Android (`com.ezoic.sdk:ezoic-cmp-sdk:1.22.3`) and 1.23.2 on iOS (`EzoicCmpSDK`). The native Android and iOS SDKs are now versioned separately. No CMP changes: released together with `ezoic_flutter_sdk` 1.22.3. There is no 1.22.1 or 1.22.2 of this package.

## 1.22.0

* First release. Wraps the native Ezoic CMP 1.22.0 (`com.ezoic.sdk:ezoic-cmp-sdk:1.22.0` on Android; `EzoicCmpSDK` from [ezoic-swift-sdk-dist](https://github.com/ezoic/ezoic-swift-sdk-dist) on iOS, through Swift Package Manager or the vendored CocoaPods XCFramework).
* `EzoicCmp`: `initialize`, `presentConsentIfRequired`, `presentConsentSettings`, `isConsentRequired`, `isPrivacyOptionsRequired` and `resetConsent`, with the same outcomes as `EzoicAds` in `ezoic_flutter_sdk`.
* The consent outcome types (`EzoicConsentOutcome` and its cases, `EzoicConsentDecision`) live here; `ezoic_flutter_sdk` re-exports them.
