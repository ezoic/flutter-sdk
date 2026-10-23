## 1.19.0

* Bump native Ezoic Ads SDK pins to 1.19.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.19.0`; iOS `EzoicAdsSDK ~> 1.19.0`). The native SDKs now send COPPA to Google Mobile Ads, IMA and Amazon, keep the device id only while consent allows storage, send a launch pageview for apps that initialize after their first screen, and no longer hold ad requests for 2 s waiting on a pageview id. Android banner and outstream views no longer destroy themselves when scrolled out of a list and reattached.
* `EzoicAds.initialize` no longer fails with "already initialized" (1002) after a hot restart. Concurrent calls share one native initialize, and a failed initialize can be retried.
* `destroy()` on a rewarded or interstitial ad that was never shown now releases the native ad, so the same ad unit can load again.
* `destroy()` on an ad that was already shown no longer stops event delivery to a newer ad for the same unit.
* `EzoicBannerView` now destroys its native banner when removed (Android and iOS).

## 1.18.0

* Bump native Ezoic Ads SDK pins to 1.18.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.18.0`; iOS `EzoicAdsSDK ~> 1.18.0`).
* `EzoicNativeAdView` now renders with the native SDKs' shared template (`EzoicNativeAdTemplateView`), so native ads look the same across Swift, Kotlin, React Native, Flutter and Capacitor apps and gain an "Ad" attribution badge.
* New `adStyle: EzoicNativeAdStyle` parameter restyles the template: background, corner radius, padding, text colors and sizes, call-to-action colors and radius, media height and the ad badge text and colors. Changing it re-renders the ad without reloading. See "Styling native ads" in the README.
* The native SDKs now report an outcome for every rewarded ad load.

## 1.17.0

* Bump native Ezoic Ads SDK pins to 1.17.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.17.0`; iOS `EzoicAdsSDK ~> 1.17.0`).
* `EzoicNativeAdView` now registers its rendered ad view with the native SDK, so native ads are reported as viewed (at least half on screen for one continuous second). No app changes needed.
* Ad reporting is more complete: viewability for every format (interstitial and rewarded at display), an outcome for every demand attempt including no-fills, Amazon fills, and the floor that filled. Full-screen ads and returning from the background no longer count as new pageviews.
* Known limitation: a `trackPageview(screen)` label for the launch screen that arrives more than ~1 s after `initialize` completes (outside a consent prompt) records a second launch pageview. Label the launch screen before `initialize` or as soon as it completes.

## 1.16.0

* Bump native Ezoic Ads SDK pins to 1.16.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.16.0`; iOS `EzoicAdsSDK ~> 1.16.0`).
* `EzoicBannerView` adds optional `refreshIntervalSeconds` (0 = off, minimum 30) and `refreshMaxCount` (0 = no limit, maximum 100). Leave them `null` to follow the Ezoic server setting; banner refresh is off unless the server or the app turns it on.
* Ad loading timeouts, retry limits and full-screen ad expiry can now be tuned from Ezoic's servers, within safe limits; without server settings the behavior matches 1.15.0. Invalid-request and missing-app-id errors now stop a load instead of retrying.

## 1.15.0

* Bump native Ezoic Ads SDK pins to 1.15.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.15.0`; iOS `EzoicAdsSDK ~> 1.15.0`).
* Google Mobile Ads moves to 25.2.0 on Android and 13.x on iOS (Google Mobile Ads 22.x for Android is past Google's sunset date). iOS builds need Xcode 26.2 or later.
* Header-bidding targeting is attached only when the bid clears the floor of each waterfall step, and impression reporting adds click counts, no-fill and creative size.

## 1.13.2

* Bump native Ezoic Ads SDK pins to 1.13.2 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.13.2`; iOS `EzoicAdsSDK ~> 1.13.2`).
* Header-bidding requests now identify Google Mobile Ads and its runtime version as the display manager (OpenRTB `imp.displaymanager` / `imp.displaymanagerver`).

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
