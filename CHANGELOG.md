## 1.13.1

* Bump native Ezoic Ads SDK pins to 1.13.1 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.13.1`; iOS `EzoicAdsSDK ~> 1.13.1`).
* iOS: Prebid header-bidding fills (including every `testMode` bid) now render at their real size; the native SDK previously left them as an invisible 1x1 creative.
* iOS: the native XCFramework no longer embeds its own copy of PrebidMobile and Google Mobile Ads, removing the `Class … is implemented in both` launch warnings and ~10 MB from app binaries. `PrebidMobile` is now pinned to 3.2.1 transitively.

## 1.13.0

* Bump native Ezoic Ads SDK pins to 1.13.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.13.0`; iOS `EzoicAdsSDK ~> 1.13.0`). Requires iOS 15.0+ and Xcode 26+.
* Built-in IAB TCF 2.4 consent dialog for users in GDPR regions (`EzoicConfiguration.cmpEnabled`, default `true`; set `false` if you run another CMP). In GDPR regions ad loads wait for a consent decision and fail with `EzoicErrorCode.consentRequired` (5001) if none is made.
* The consent dialog is presented automatically once after `initialize` succeeds (`EzoicConfiguration.autoPresentConsent`, default `true`).
* New consent API: `EzoicAds.presentConsentIfRequired()`, `presentConsentSettings()` (wire it to a persistent "Privacy settings" entry point, as TCF requires), `isConsentRequired()` and `resetConsent()`, with the `EzoicConsentOutcome` sealed class and `EzoicConsentDecision`.
* `EzoicAds.trackPageview([screen])` labels pageviews (and the ads on that screen) per route; `EzoicConfiguration.autoTrackPageviews` (default `true`) turns off the native SDK's own host-screen pageviews.
* Android: `initialize`, rewarded load and interstitial load failures now carry the native `EzoicError` code in `PlatformException.details` (previously the error's string form), matching iOS.
* iOS: the plugin podspec declares `static_framework = true`, so the template `use_frameworks!` Podfile works without `:linkage => :static`.
* `setGDPRConsent` must now be called before `initialize` on every launch (or set `cmpEnabled: false`) for the built-in CMP to stand down.
* README: requirements, git installation, initialization, consent, pageview labelling and error codes.

## 1.11.1

* Pin the native iOS SDK to 1.11.x. Native 1.13.0 introduces a built-in consent dialog that this wrapper cannot yet configure; it will be adopted in wrapper 1.13.0.
* Raise the iOS minimum deployment target to 15.0 (Xcode 27 floor).

## 1.11.0

* `EzoicRewardedAd.show` takes an optional `rewardName`. Pass the reward you offer so rewarded reports can group by that name.
* Closing a rewarded ad before the reward is granted is now reported. Skipped ads show up in rewarded reports.
* Bump native Ezoic Ads SDK pins to 1.11.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.11.0`; iOS `EzoicAdsSDK ~> 1.10` already resolves 1.11.0).

## 1.10.1

* Fix impression reporting: the impression event now reports the ad unit path without the network-code prefix, so rendered app impressions are counted correctly in Ezoic reporting. No API change.
* Bump native Ezoic Ads SDK pins to 1.10.1 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.10.1`; iOS `EzoicAdsSDK ~> 1.10` already resolves 1.10.1).

## 1.10.0

* Rewarded ads now report their lifecycle (request, start, reward granted, close, failed-to-show) so rewarded performance can be tracked per placement. No API change.
* Bump native Ezoic Ads SDK pins to 1.10.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.10.0`, iOS `EzoicAdsSDK ~> 1.10`).

## 1.9.1

* Rewarded ads now pass a server-issued rewarded impression id to Google Mobile Ads as the server-side verification (SSV) `user_id`, so SSV callbacks for rewarded completions can be matched. No API change.
* Bump native Ezoic Ads SDK pins to 1.9.1 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.9.1`, iOS `EzoicAdsSDK ~> 1.9`).

## 1.9.0

* Collapse unfilled banner and outstream ad views (`collapseOnNoFill`, default true). Widgets drop to zero size on a terminal no-fill; `onSizeChange` reports the displayed creative size (or 0×0 when collapsed). Native SDKs keep the previous creative through a failed refresh.
* Bump native Ezoic Ads SDK pins to 1.9.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.9.0`, iOS `EzoicAdsSDK ~> 1.9`).

## 1.8.0

* Bump native Ezoic Ads SDK pins to 1.8.0. `testMode` now also requests $0.00 Ezoic test-ad fill on no-demand auctions (development builds / simulators only); the first auction is still a real auction.

## 1.7.0

* Bump native SDK pins to 1.7.0. Prebid floor gate: the native SDKs now attach Prebid keywords to the GAM request only when the Prebid bid meets the current eb_br rung floor (Google-only requests otherwise), mirroring web adjustHbValues; ad-unit config parses the new `targeting_floors` array parallel to `targeting_hashes`. Prebid Mobile demand is fetched once per load.

## [1.6.1] - 2026-09-02

* Bump native SDK pins to 1.6.1 (AppSDK/BundleId on ad-config requests; imp.ext.ezoic identity echo on auction imps).
- Native SDKs now fit the Prebid creative size to the ad view width before resizing (outstream video fills the frame; no more clipped 640x360 creatives).

## 1.5.0

* Amazon Publisher Services (APS) header bidding passthrough for banner ads. When a placement's remote configuration includes APS parameters, the native SDKs run the Amazon bid alongside Prebid automatically — no Flutter-side changes required.
* Bump the native Ezoic Ads SDK dependency to 1.5.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.5.0`, iOS `EzoicAdsSDK ~> 1.5`).

## 1.4.0

* Add `EzoicOutstreamAdView` (platform-view widget rendering the native outstream video unit with load/error/impression/click/open/close callbacks).
* Add `EzoicInstreamAd` (view-less controller: `load` resolves the GAM VAST ad-tag URL, `getNextAdTagUrl` walks the floor waterfall, `reportImpression` fires the render pixel, `destroy`) wrapping the native multi-use instream video unit.
* Bump the native Ezoic Ads SDK dependency to 1.4.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.4.0`, iOS `EzoicAdsSDK ~> 1.4`).

## 1.3.0

* Add `EzoicNativeAdView` (platform-view widget rendering an SDK-built template native ad with load/error/impression/click/open/close callbacks) wrapping the native 1.3.0 native ad units.
* Bump the native Ezoic Ads SDK dependency to 1.3.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.3.0`, iOS `EzoicAdsSDK ~> 1.3`).

## 1.2.0

* Add `EzoicInterstitialAd` (load/show/destroy + lifecycle callbacks) wrapping the native 1.2.0 interstitial ad units.
* Bump the native Ezoic Ads SDK dependency to 1.2.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.2.0`, iOS `EzoicAdsSDK ~> 1.2`).

## 0.0.1

* TODO: Describe initial release.
